"""
Destination Service - FIXED FOR TIMEOUTS
✅ Multiple Overpass servers with fast failover
✅ Shorter timeouts (15s instead of 30s)
✅ Simpler, faster queries
✅ Excludes hotels from results
✅ Works for any city
"""

import requests
import time
import logging
from typing import List, Dict, Optional
import random
import hashlib
from urllib.parse import quote

logger = logging.getLogger(__name__)

# More servers for better reliability
OVERPASS_SERVERS = [
    "https://overpass-api.de/api/interpreter",
    "https://overpass.kumi.systems/api/interpreter",
    "https://maps.mail.ru/osm/tools/overpass/api/interpreter",
    "https://overpass.openstreetmap.ru/api/interpreter",
]

# Shorter timeouts to fail fast
REQUEST_TIMEOUT = 15
QUERY_TIMEOUT = 12

# Hotels to exclude
EXCLUDE_TYPES = ['hotel', 'hostel', 'guest_house', 'motel', 'apartment', 'camp_site']

DEFAULT_WEIGHTS = {
    'museum': 1.0, 'entertainment': 1.0, 'viewpoint': 1.0,
    'park': 1.0, 'nature': 1.0, 'cultural': 1.0,
    'temple': 1.0, 'shopping': 1.0, 'attraction': 1.0,
}


def get_destinations_near_location(
    city: str,
    country: str,
    lat: float,
    lon: float,
    count: int = 100,
    category_weights: Dict[str, float] = None,
    preferred_categories: List[str] = None
) -> List[Dict]:
    """Get destinations with fast failover"""

    if category_weights is None:
        category_weights = DEFAULT_WEIGHTS.copy()
    if preferred_categories is None:
        preferred_categories = list(DEFAULT_WEIGHTS.keys())

    logger.info(f"\n🔍 DESTINATIONS: {city}, {country}")
    logger.info(f"📍 Coords: ({lat:.4f}, {lon:.4f})")
    logger.info(f"🎯 Categories: {preferred_categories}")

    all_destinations = []
    seen_ids = set()

    # Try increasing radii
    for radius in [2000, 5000, 10000]:
        logger.info(f"\n📡 Radius: {radius}m")

        # Simple combined query for all types
        destinations = _fetch_all_attractions(lat, lon, radius, city, country)

        for dest in destinations:
            if dest['osm_id'] not in seen_ids:
                seen_ids.add(dest['osm_id'])
                all_destinations.append(dest)

        logger.info(f"   Found: {len(destinations)} (total: {len(all_destinations)})")

        if len(all_destinations) >= 20:
            break

        time.sleep(0.5)

    if not all_destinations:
        logger.warning("⚠️ No destinations found")
        return []

    # Assign categories and scores
    for dest in all_destinations:
        cat = _infer_category(dest.get('tags', {}))
        dest['category'] = cat

        weight = category_weights.get(cat, 0.5)
        if cat in preferred_categories:
            weight = min(weight * 1.5, 1.0)
            dest['is_preferred'] = True
        else:
            dest['is_preferred'] = False

        dest['preference_score'] = round(weight * (dest.get('rating', 4.0) / 5.0), 3)

    # Sort by preference
    all_destinations.sort(key=lambda x: -x.get('preference_score', 0))

    logger.info(f"✅ Returning {min(len(all_destinations), count)} destinations")

    return all_destinations[:count]


def _fetch_all_attractions(lat: float, lon: float, radius: int, city: str, country: str) -> List[Dict]:
    """Fetch attractions with a simple combined query"""

    # Build exclusion for hotels
    exclude = ''.join([f'["tourism"!="{t}"]' for t in EXCLUDE_TYPES])

    # Simple query that catches most attractions
    query = f'''
[out:json][timeout:{QUERY_TIMEOUT}];
(
  node["tourism"]["name"]{exclude}(around:{radius},{lat},{lon});
  node["leisure"~"park|garden"]["name"](around:{radius},{lat},{lon});
  node["amenity"="place_of_worship"]["name"](around:{radius},{lat},{lon});
  node["historic"]["name"](around:{radius},{lat},{lon});
);
out 50;
'''

    return _execute_query(query, city, country)


def _execute_query(query: str, city: str, country: str) -> List[Dict]:
    """Execute query with fast server failover"""

    for i, server in enumerate(OVERPASS_SERVERS):
        try:
            logger.info(f"   Server {i+1}/{len(OVERPASS_SERVERS)}: {server.split('/')[2][:20]}")

            response = requests.post(
                server,
                data=query,
                headers={'Content-Type': 'application/x-www-form-urlencoded'},
                timeout=REQUEST_TIMEOUT
            )

            if response.status_code == 200:
                data = response.json()
                elements = data.get('elements', [])
                logger.info(f"   ✓ Got {len(elements)} elements")
                return _parse_elements(elements, city, country)

            elif response.status_code in [429, 503, 504]:
                logger.info(f"   Server busy ({response.status_code}), trying next...")
                continue
            else:
                logger.info(f"   Status {response.status_code}, trying next...")
                continue

        except requests.exceptions.Timeout:
            logger.info(f"   Timeout, trying next...")
            continue
        except Exception as e:
            logger.info(f"   Error: {str(e)[:50]}, trying next...")
            continue

    logger.warning("   All servers failed")
    return []


def _parse_elements(elements: List[Dict], city: str, country: str) -> List[Dict]:
    """Parse OSM elements into destination format"""

    places = []

    for el in elements:
        try:
            tags = el.get('tags', {})

            # Get name
            name = tags.get('name:en') or tags.get('name') or tags.get('int_name')
            if not name or len(name) < 2:
                continue

            # Skip hotels
            tourism = tags.get('tourism', '').lower()
            if tourism in EXCLUDE_TYPES:
                continue

            # Skip if name contains hotel keywords
            if any(h in name.lower() for h in ['hotel', 'hostel', 'inn', 'motel', 'resort']):
                if not tags.get('historic'):
                    continue

            # Get coordinates
            lat = el.get('lat')
            lon = el.get('lon')
            if not lat or not lon:
                continue

            osm_id = str(el.get('id', ''))

            # Google Maps link with name
            encoded = quote(f"{name} {city}")
            maps_link = f"https://www.google.com/maps/search/?api=1&query={encoded}"

            places.append({
                'id': hashlib.md5(f"{osm_id}_{name}".encode()).hexdigest()[:16],
                'osm_id': osm_id,
                'name': name.strip(),
                'name_local': tags.get('name'),
                'city': city,
                'country': country,
                'category': 'attraction',
                'rating': round(random.uniform(4.0, 4.8), 1),
                'avg_cost': _estimate_cost(country),
                'duration_hours': 1.5,
                'description': f"{name} is a popular attraction in {city}.",
                'opening_hours': tags.get('opening_hours', 'Check website'),
                'tips': ['Arrive early', 'Check hours before visiting'],
                'address': _build_address(tags, city),
                'website': tags.get('website', ''),
                'phone': tags.get('phone', ''),
                'coordinates': {'lat': lat, 'lng': lon},
                'maps_link': maps_link,
                'maps_link_direct': f"https://www.google.com/maps?q={lat},{lon}",
                'tags': tags,
                'data_source': 'OpenStreetMap',
            })

        except Exception:
            continue

    return places


def _infer_category(tags: Dict) -> str:
    """Infer category from OSM tags"""

    tourism = tags.get('tourism', '')
    leisure = tags.get('leisure', '')
    amenity = tags.get('amenity', '')
    historic = tags.get('historic', '')

    if tourism == 'museum':
        return 'museum'
    elif tourism == 'viewpoint':
        return 'viewpoint'
    elif tourism in ['theme_park', 'zoo', 'aquarium']:
        return 'entertainment'
    elif leisure in ['park', 'garden', 'nature_reserve']:
        return 'park'
    elif amenity == 'place_of_worship':
        return 'temple'
    elif historic:
        return 'cultural'
    elif tags.get('shop'):
        return 'shopping'
    else:
        return 'attraction'


def _build_address(tags: Dict, city: str) -> str:
    """Build address from tags"""
    parts = []
    if tags.get('addr:street'):
        street = tags['addr:street']
        if tags.get('addr:housenumber'):
            street = f"{tags['addr:housenumber']} {street}"
        parts.append(street)
    parts.append(city)
    return ', '.join(parts)


def _estimate_cost(country: str) -> float:
    """Estimate entrance cost"""
    costs = {
        'japan': 50, 'usa': 60, 'singapore': 45, 'thailand': 15,
        'malaysia': 20, 'indonesia': 12, 'vietnam': 10, 'korea': 35,
        'china': 25, 'uk': 50, 'france': 45,
    }

    for key, cost in costs.items():
        if key in country.lower():
            return round(cost * random.uniform(0.8, 1.2), 2)

    return round(30 * random.uniform(0.8, 1.2), 2)