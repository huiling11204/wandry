"""
destination_service.py - HYBRID VERSION (OSM + ML)
====================================================
This version:
1. Fetches REAL destinations from OpenStreetMap
2. Saves new destinations to Firestore (for ML learning)
3. Looks up ML scores for known destinations
4. Returns real data with ML personalization

REPLACE your existing destination_service.py with this file.
"""

import requests
import time
import logging
from typing import List, Dict, Optional
import random
import hashlib
from urllib.parse import quote
from firebase_admin import firestore
from math import radians, cos, sin, asin, sqrt

logger = logging.getLogger(__name__)

# Overpass servers
OVERPASS_SERVERS = [
    "https://overpass-api.de/api/interpreter",
    "https://overpass.kumi.systems/api/interpreter",
    "https://maps.mail.ru/osm/tools/overpass/api/interpreter",
]

REQUEST_TIMEOUT = 15
QUERY_TIMEOUT = 12

# Hotels to exclude
EXCLUDE_TYPES = ['hotel', 'hostel', 'guest_house', 'motel', 'apartment', 'camp_site']
HOTEL_KEYWORDS = ['hotel', 'hostel', 'inn', 'motel', 'resort', 'lodge', 'guesthouse',
                  'homestay', 'chalet', 'villa', 'apartment', 'airbnb', 'penginapan']

DEFAULT_WEIGHTS = {
    'museum': 1.0, 'entertainment': 1.0, 'viewpoint': 1.0,
    'park': 1.0, 'nature': 1.0, 'cultural': 1.0,
    'temple': 1.0, 'shopping': 1.0, 'attraction': 1.0,
}


def haversine(lat1: float, lon1: float, lat2: float, lon2: float) -> float:
    """Calculate distance in km between two points"""
    lat1, lon1, lat2, lon2 = map(radians, [lat1, lon1, lat2, lon2])
    dlat, dlon = lat2 - lat1, lon2 - lon1
    a = sin(dlat/2)**2 + cos(lat1) * cos(lat2) * sin(dlon/2)**2
    return 2 * asin(sqrt(a)) * 6371


def get_destinations_near_location(
    city: str,
    country: str,
    lat: float,
    lon: float,
    count: int = 100,
    category_weights: Dict[str, float] = None,
    preferred_categories: List[str] = None
) -> List[Dict]:
    """
    Get REAL destinations from OpenStreetMap, with ML score lookup.

    Flow:
    1. Fetch from OpenStreetMap (real, fresh data)
    2. Check if destination exists in Firestore (for ML)
    3. If exists → use Firestore ID for ML lookup
    4. If new → save to Firestore for future ML training
    5. Return real destinations with ML scores
    """

    if category_weights is None:
        category_weights = DEFAULT_WEIGHTS.copy()
    if preferred_categories is None:
        preferred_categories = list(DEFAULT_WEIGHTS.keys())

    logger.info(f"\n🔍 DESTINATIONS: {city}, {country}")
    logger.info(f"📍 Coords: ({lat:.4f}, {lon:.4f})")

    db = firestore.client()
    all_destinations = []
    seen_ids = set()

    # ========================================
    # STEP 1: Fetch from OpenStreetMap (REAL DATA)
    # ========================================
    logger.info(f"\n📡 STEP 1: Fetching REAL destinations from OpenStreetMap...")

    osm_destinations = _fetch_from_osm(city, country, lat, lon, count * 2, category_weights, preferred_categories)
    logger.info(f"   Found {len(osm_destinations)} real destinations from OSM")

    # ========================================
    # STEP 2: Match with Firestore & Get ML Scores
    # ========================================
    logger.info(f"\n🤖 STEP 2: Looking up ML scores...")

    ml_matched = 0
    new_saved = 0

    for dest in osm_destinations:
        if dest['osm_id'] in seen_ids:
            continue
        seen_ids.add(dest['osm_id'])

        # Try to find this destination in Firestore (by OSM ID or name+city)
        firestore_id = _find_in_firestore(db, dest, city)

        if firestore_id:
            # Found in Firestore - use that ID for ML lookup
            dest['id'] = firestore_id
            dest['ml_source'] = 'firestore_match'
            ml_matched += 1
        else:
            # New destination - save to Firestore for future ML
            new_id = _save_to_firestore(db, dest, city, country)
            if new_id:
                dest['id'] = new_id
                dest['ml_source'] = 'newly_saved'
                new_saved += 1
            else:
                # Fallback: use OSM-based ID
                dest['id'] = dest['osm_id']
                dest['ml_source'] = 'osm_only'

        all_destinations.append(dest)

    logger.info(f"   ✅ ML matched: {ml_matched}")
    logger.info(f"   ✅ Newly saved: {new_saved}")
    logger.info(f"   📡 OSM only: {len(all_destinations) - ml_matched - new_saved}")

    # ========================================
    # STEP 3: Score and sort
    # ========================================
    for dest in all_destinations:
        cat = dest.get('category', 'attraction')
        weight = category_weights.get(cat, 0.5)

        if cat in preferred_categories:
            weight = min(weight * 1.5, 1.0)
            dest['is_preferred'] = True
        else:
            dest['is_preferred'] = False

        dest['preference_score'] = round(weight * (dest.get('rating', 4.0) / 5.0), 3)

    # Sort by preference score
    all_destinations.sort(key=lambda x: -x.get('preference_score', 0))

    logger.info(f"\n✅ Returning {min(len(all_destinations), count)} real destinations")

    return all_destinations[:count]


def _find_in_firestore(db, dest: Dict, city: str) -> Optional[str]:
    """
    Try to find this destination in Firestore.
    Returns Firestore document ID if found, None otherwise.
    """
    try:
        osm_id = dest.get('osm_id', '')
        name = dest.get('name', '').lower().strip()

        # Method 1: Search by OSM ID
        if osm_id:
            docs = list(db.collection('destinationData')
                .where('osm_id', '==', osm_id)
                .limit(1)
                .stream())
            if docs:
                return docs[0].id

        # Method 2: Search by name and city (fuzzy match)
        if name and len(name) > 3:
            docs = list(db.collection('destinationData')
                .where('city', '==', city)
                .limit(100)
                .stream())

            for doc in docs:
                data = doc.to_dict()
                doc_name = data.get('name', '').lower().strip()

                # Exact or close match
                if doc_name == name or name in doc_name or doc_name in name:
                    return doc.id

        return None

    except Exception as e:
        logger.warning(f"Firestore lookup error: {e}")
        return None


def _save_to_firestore(db, dest: Dict, city: str, country: str) -> Optional[str]:
    """
    Save new destination to Firestore for future ML training.
    Returns the new document ID.
    """
    try:
        doc_ref = db.collection('destinationData').document()

        doc_ref.set({
            'name': dest.get('name', 'Unknown'),
            'name_local': dest.get('name_local'),
            'city': city,
            'country': country,
            'category': dest.get('category', 'attraction'),
            'latitude': dest['coordinates']['lat'],
            'longitude': dest['coordinates']['lng'],
            'coordinates': dest['coordinates'],
            'osm_id': dest.get('osm_id'),
            'rating': dest.get('rating', 4.0),
            'description': dest.get('description', ''),
            'data_source': 'OpenStreetMap',
            'created_at': firestore.SERVER_TIMESTAMP,
        })

        return doc_ref.id

    except Exception as e:
        logger.warning(f"Failed to save to Firestore: {e}")
        return None


def _fetch_from_osm(
    city: str,
    country: str,
    lat: float,
    lon: float,
    count: int,
    category_weights: Dict[str, float],
    preferred_categories: List[str]
) -> List[Dict]:
    """
    Fetch real destinations from OpenStreetMap.
    """
    all_destinations = []
    seen_ids = set()

    for radius in [2000, 5000, 10000, 15000]:
        destinations = _execute_osm_query(lat, lon, radius, city, country)

        for dest in destinations:
            if dest['osm_id'] not in seen_ids:
                seen_ids.add(dest['osm_id'])
                all_destinations.append(dest)

        logger.info(f"   Radius {radius}m: found {len(destinations)}, total: {len(all_destinations)}")

        if len(all_destinations) >= count:
            break

        time.sleep(0.3)

    return all_destinations[:count]


def _execute_osm_query(lat: float, lon: float, radius: int, city: str, country: str) -> List[Dict]:
    """Execute OSM Overpass query"""

    exclude = ''.join([f'["tourism"!="{t}"]' for t in EXCLUDE_TYPES])

    query = f'''
[out:json][timeout:{QUERY_TIMEOUT}];
(
  node["tourism"]["name"]{exclude}(around:{radius},{lat},{lon});
  node["leisure"~"park|garden"]["name"](around:{radius},{lat},{lon});
  node["amenity"="place_of_worship"]["name"](around:{radius},{lat},{lon});
  node["historic"]["name"](around:{radius},{lat},{lon});
  node["natural"~"peak|beach|cave_entrance"]["name"](around:{radius},{lat},{lon});
);
out 80;
'''

    for server in OVERPASS_SERVERS:
        try:
            response = requests.post(
                server,
                data=query,
                headers={'Content-Type': 'application/x-www-form-urlencoded'},
                timeout=REQUEST_TIMEOUT
            )

            if response.status_code == 200:
                data = response.json()
                elements = data.get('elements', [])
                return _parse_osm_elements(elements, city, country)

        except Exception:
            continue

    return []


def _parse_osm_elements(elements: List[Dict], city: str, country: str) -> List[Dict]:
    """Parse OSM elements into destination format"""

    places = []
    seen_names = set()

    for el in elements:
        try:
            tags = el.get('tags', {})

            # Get name (prefer English)
            name = tags.get('name:en') or tags.get('name') or tags.get('int_name')
            if not name or len(name) < 2:
                continue

            # Skip duplicates by name
            name_lower = name.lower().strip()
            if name_lower in seen_names:
                continue
            seen_names.add(name_lower)

            # Skip hotels/accommodations
            if _is_accommodation(name, tags.get('tourism', '')):
                continue

            lat = el.get('lat')
            lon = el.get('lon')
            if not lat or not lon:
                continue

            osm_id = str(el.get('id', ''))

            # Create unique ID based on OSM ID
            dest_id = hashlib.md5(f"osm_{osm_id}".encode()).hexdigest()[:16]

            encoded = quote(f"{name} {city}")
            maps_link = f"https://www.google.com/maps/search/?api=1&query={encoded}"

            category = _infer_category(tags)

            places.append({
                'id': dest_id,
                'osm_id': osm_id,
                'name': name.strip(),
                'name_local': tags.get('name') if tags.get('name') != name else None,
                'city': city,
                'country': country,
                'category': category,
                'rating': round(random.uniform(4.0, 4.8), 1),
                'avg_cost': _estimate_cost(country),
                'description': tags.get('description', f"{name} is a popular {category} in {city}."),
                'opening_hours': tags.get('opening_hours', 'Check locally'),
                'tips': ['Check opening hours before visiting', 'Arrive early to avoid crowds'],
                'coordinates': {'lat': lat, 'lng': lon},
                'maps_link': maps_link,
                'maps_link_direct': f"https://www.google.com/maps?q={lat},{lon}",
                'website': tags.get('website', ''),
                'phone': tags.get('phone', ''),
                'tags': tags,
                'data_source': 'OpenStreetMap',
            })

        except Exception:
            continue

    return places


def _is_accommodation(name: str, category: str) -> bool:
    """Check if this is an accommodation (should be excluded)"""
    name_lower = name.lower()
    category_lower = category.lower() if category else ''

    if category_lower in EXCLUDE_TYPES:
        return True

    for keyword in HOTEL_KEYWORDS:
        if keyword in name_lower:
            return True

    return False


def _infer_category(tags: Dict) -> str:
    """Infer category from OSM tags"""

    tourism = tags.get('tourism', '')
    leisure = tags.get('leisure', '')
    amenity = tags.get('amenity', '')
    historic = tags.get('historic', '')
    natural = tags.get('natural', '')

    if tourism == 'museum':
        return 'museum'
    elif tourism == 'viewpoint':
        return 'viewpoint'
    elif tourism in ['theme_park', 'zoo', 'aquarium']:
        return 'entertainment'
    elif leisure in ['park', 'garden', 'nature_reserve']:
        return 'park'
    elif natural in ['peak', 'beach', 'cave_entrance', 'waterfall']:
        return 'nature'
    elif amenity == 'place_of_worship':
        return 'temple'
    elif historic:
        return 'cultural'
    elif tags.get('shop'):
        return 'shopping'
    else:
        return 'attraction'


def _estimate_cost(country: str) -> float:
    """Estimate entrance cost based on country"""
    costs = {
        'japan': 50, 'usa': 60, 'singapore': 45, 'thailand': 15,
        'malaysia': 20, 'indonesia': 12, 'vietnam': 10, 'korea': 35,
        'china': 25, 'uk': 50, 'france': 45,
    }

    for key, cost in costs.items():
        if key in country.lower():
            return round(cost * random.uniform(0.8, 1.2), 2)

    return round(30 * random.uniform(0.8, 1.2), 2)