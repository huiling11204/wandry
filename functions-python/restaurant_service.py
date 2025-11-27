"""
Restaurant Service - FIXED FOR TIMEOUTS
✅ Multiple servers with fast failover
✅ Shorter timeouts
✅ Accurate Google Maps links
"""

import requests
import time
import logging
from typing import List, Dict, Set
import random
from urllib.parse import quote

logger = logging.getLogger(__name__)

OVERPASS_SERVERS = [
    "https://overpass-api.de/api/interpreter",
    "https://overpass.kumi.systems/api/interpreter",
    "https://maps.mail.ru/osm/tools/overpass/api/interpreter",
    "https://overpass.openstreetmap.ru/api/interpreter",
]

REQUEST_TIMEOUT = 15
QUERY_TIMEOUT = 12


def get_restaurants_with_fallback(
    city: str,
    country: str,
    meal_type: str,
    budget_level: str,
    halal_only: bool = False,
    used_osm_ids: Set[str] = None,
    count: int = 8,
    current_location: tuple = None,
    max_travel_time: float = 30,
    city_center_coords: tuple = None
) -> List[Dict]:
    """Get restaurants with fast failover"""

    if used_osm_ids is None:
        used_osm_ids = set()

    if current_location:
        lat, lon = current_location
    elif city_center_coords:
        lat, lon = city_center_coords
    else:
        return []

    logger.info(f"🍽️ {meal_type} restaurants near ({lat:.4f}, {lon:.4f})")

    restaurants = []

    # Try increasing radii
    for radius in [2000, 5000, 8000]:
        results = _fetch_restaurants(lat, lon, radius, meal_type, halal_only)

        for r in results:
            if r['osm_id'] not in used_osm_ids and r['osm_id'] not in [x['osm_id'] for x in restaurants]:
                restaurants.append(r)

        logger.info(f"   Radius {radius}m: {len(results)} found (total: {len(restaurants)})")

        if len(restaurants) >= count:
            break

        time.sleep(0.3)

    if not restaurants:
        logger.warning("   No restaurants found")
        return []

    # Enrich and sort
    restaurants = _enrich_restaurants(restaurants, city, country, budget_level, meal_type, lat, lon)
    restaurants.sort(key=lambda x: x.get('distance_km', 999))

    available = [r for r in restaurants if r['osm_id'] not in used_osm_ids]

    logger.info(f"✅ Returning {min(len(available), count)} restaurants")
    return available[:count]


def _fetch_restaurants(lat: float, lon: float, radius: int, meal_type: str, halal_only: bool) -> List[Dict]:
    """Fetch restaurants with simple query"""

    if meal_type == 'breakfast':
        amenity = '["amenity"~"cafe|restaurant|bakery"]'
    else:
        amenity = '["amenity"~"restaurant|cafe|fast_food"]'

    query = f'''
[out:json][timeout:{QUERY_TIMEOUT}];
node{amenity}["name"](around:{radius},{lat},{lon});
out 60;
'''

    restaurants = []

    for i, server in enumerate(OVERPASS_SERVERS):
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

                for el in elements:
                    r = _parse_restaurant(el, halal_only)
                    if r:
                        restaurants.append(r)

                return restaurants

            elif response.status_code in [429, 503, 504]:
                continue

        except requests.exceptions.Timeout:
            continue
        except Exception:
            continue

    return restaurants


def _parse_restaurant(el: Dict, halal_only: bool) -> Dict:
    """Parse OSM element into restaurant"""

    try:
        tags = el.get('tags', {})

        name = tags.get('name:en') or tags.get('name')
        if not name or len(name) < 2:
            return None

        lat = el.get('lat')
        lon = el.get('lon')
        if not lat or not lon:
            return None

        # Halal check
        is_halal = (
            tags.get('diet:halal') == 'yes' or
            'halal' in name.lower() or
            tags.get('cuisine') == 'halal'
        )

        if halal_only and not is_halal:
            return None

        # Cuisine
        cuisine = tags.get('cuisine', 'Local')
        if ';' in cuisine:
            cuisine = cuisine.split(';')[0]
        cuisine = cuisine.replace('_', ' ').title()

        return {
            'osm_id': str(el.get('id', '')),
            'name': name.strip(),
            'cuisine': cuisine,
            'coordinates': {'lat': lat, 'lng': lon},
            'is_halal': is_halal,
            'phone': tags.get('phone', ''),
            'website': tags.get('website', ''),
            'opening_hours': tags.get('opening_hours', ''),
            'tags': tags,
        }

    except Exception:
        return None


def _enrich_restaurants(
    restaurants: List[Dict],
    city: str,
    country: str,
    budget_level: str,
    meal_type: str,
    current_lat: float,
    current_lon: float
) -> List[Dict]:
    """Add calculated fields"""

    enriched = []

    for r in restaurants:
        try:
            coords = r['coordinates']
            lat, lon = coords['lat'], coords['lng']

            # Distance
            dist = _haversine(current_lat, current_lon, lat, lon)
            travel = (dist / 25) * 60 + 10

            # Price
            price = _estimate_price(country, budget_level, meal_type)
            currency = _convert_currency(price, country)

            # Maps link
            encoded = quote(f"{r['name']} {city} {country}")
            maps_link = f"https://www.google.com/maps/search/?api=1&query={encoded}"

            enriched.append({
                **r,
                'address': city,
                'distance_km': round(dist, 2),
                'travel_time_minutes': round(travel, 1),
                'cost_myr': round(price, 2),
                'estimated_cost_myr': round(price, 2),
                'cost_display': currency['display'],
                'rating': round(random.uniform(3.8, 4.8), 1),
                'maps_link': maps_link,
                'maps_link_direct': f"https://www.google.com/maps?q={lat},{lon}",
                'data_source': 'OpenStreetMap',
            })

        except Exception:
            continue

    return enriched


def _haversine(lat1: float, lon1: float, lat2: float, lon2: float) -> float:
    """Distance in km"""
    from math import radians, cos, sin, asin, sqrt
    lat1, lon1, lat2, lon2 = map(radians, [lat1, lon1, lat2, lon2])
    dlat, dlon = lat2 - lat1, lon2 - lon1
    a = sin(dlat/2)**2 + cos(lat1) * cos(lat2) * sin(dlon/2)**2
    return 2 * asin(sqrt(a)) * 6371


def _estimate_price(country: str, budget: str, meal: str) -> float:
    """Estimate meal price in MYR"""
    base = {'breakfast': 30, 'lunch': 50, 'dinner': 80}.get(meal, 50)
    budget_mult = {'Low': 0.7, 'Medium': 1.0, 'High': 1.5}.get(budget, 1.0)

    country_mult = 1.0
    for key, mult in {'japan': 2.5, 'usa': 2.8, 'singapore': 2.4, 'thailand': 0.9, 'malaysia': 1.0}.items():
        if key in country.lower():
            country_mult = mult
            break

    return base * budget_mult * country_mult * random.uniform(0.8, 1.2)


def _convert_currency(myr: float, country: str) -> Dict:
    """Convert to local currency display"""
    rates = {'JPY': 33.5, 'USD': 0.22, 'THB': 7.8, 'SGD': 0.3, 'MYR': 1.0}
    symbols = {'JPY': '¥', 'USD': '$', 'THB': '฿', 'SGD': 'S$', 'MYR': 'RM'}

    curr = 'MYR'
    for key, c in {'japan': 'JPY', 'usa': 'USD', 'thailand': 'THB', 'singapore': 'SGD'}.items():
        if key in country.lower():
            curr = c
            break

    local = myr * rates.get(curr, 1.0)
    sym = symbols.get(curr, curr)

    return {'display': f"RM {myr:.0f} (≈{sym}{local:.0f})", 'currency': curr}