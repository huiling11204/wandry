"""
Restaurant Service - Find restaurants with dynamic pricing

SIMPLE EXPLANATION:
- Uses OpenStreetMap (OSM) API to find restaurants
- Multiple backup servers for reliability
- Estimates prices based on country, cuisine, and meal type
- Sometimes finds VERIFIED prices in OSM data
- Falls back to climate-adjusted estimates when needed

PRICING SYSTEM:
1. Check OSM for explicit price tags (rare but accurate)
2. Check OSM for price level indicators ($, $$, $$$)
3. Estimate based on cuisine type (fast food = cheap, sushi = expensive)
4. Fall back to country/budget-based estimation
"""

import requests
import time
import logging
from typing import List, Dict, Set
import random
from urllib.parse import quote

logger = logging.getLogger(__name__)

# Multiple Overpass API servers - if one is slow/down, try next
OVERPASS_SERVERS = [
    "https://overpass-api.de/api/interpreter",
    "https://overpass.kumi.systems/api/interpreter",
    "https://maps.mail.ru/osm/tools/overpass/api/interpreter",
    "https://overpass.openstreetmap.ru/api/interpreter",
]

REQUEST_TIMEOUT = 15  # Max wait time for server response
QUERY_TIMEOUT = 12    # Max time server should spend processing query

# Base prices per meal in different countries (in Malaysian Ringgit)
# These are rough averages for a typical meal
COUNTRY_BASE_PRICES = {
    'malaysia': {'cheap': 15, 'moderate': 35, 'expensive': 80},
    'singapore': {'cheap': 25, 'moderate': 55, 'expensive': 120},
    'thailand': {'cheap': 12, 'moderate': 30, 'expensive': 70},
    'indonesia': {'cheap': 10, 'moderate': 25, 'expensive': 60},
    'vietnam': {'cheap': 8, 'moderate': 22, 'expensive': 55},
    'japan': {'cheap': 35, 'moderate': 75, 'expensive': 180},
    'korea': {'cheap': 30, 'moderate': 60, 'expensive': 140},
    'china': {'cheap': 15, 'moderate': 40, 'expensive': 100},
    'usa': {'cheap': 45, 'moderate': 90, 'expensive': 200},
    'uk': {'cheap': 40, 'moderate': 80, 'expensive': 180},
    # ... more countries omitted for brevity
}

DEFAULT_PRICES = {'cheap': 25, 'moderate': 50, 'expensive': 110}


def get_restaurants_with_fallback(
    city: str,
    country: str,
    meal_type: str,
    budget_level: str,
    used_osm_ids: Set[str] = None,
    count: int = 8,
    current_location: tuple = None,
    max_travel_time: float = 30,
    city_center_coords: tuple = None
) -> List[Dict]:
    """
    Main function to find restaurants near a location

    Args:
        city: City name (e.g., 'Tokyo')
        country: Country name (e.g., 'Japan')
        meal_type: 'breakfast', 'lunch', 'dinner', 'snack', or 'cafe'
        budget_level: 'Low', 'Medium', or 'High'
        used_osm_ids: Set of restaurant IDs already used (to avoid duplicates)
        count: How many restaurants to return
        current_location: (lat, lon) - where you are now
        max_travel_time: Not used in current implementation
        city_center_coords: (lat, lon) - fallback location if current_location is None

    Returns:
        List of restaurant dictionaries with:
        - name, cuisine, coordinates
        - cost_myr, cost_display, price_verified
        - distance_km, travel_time_minutes
        - maps_link, rating, etc.

    How it works:
    1. Search in expanding circles (2km → 5km → 8km) until we find enough
    2. Enrich with pricing, distance, and Google Maps links
    3. Sort by distance (closest first)
    4. Filter out already-used restaurants
    """

    if used_osm_ids is None:
        used_osm_ids = set()

    # Determine search center
    if current_location:
        lat, lon = current_location
    elif city_center_coords:
        lat, lon = city_center_coords
    else:
        return []  # No location provided

    logger.info(f"🍽️ {meal_type} restaurants near ({lat:.4f}, {lon:.4f})")

    restaurants = []

    # Try increasing search radii until we find enough restaurants
    for radius in [2000, 5000, 8000]:  # 2km, 5km, 8km
        results = _fetch_restaurants(lat, lon, radius, meal_type)

        # Add new (non-duplicate) restaurants
        for r in results:
            if r['osm_id'] not in used_osm_ids and r['osm_id'] not in [x['osm_id'] for x in restaurants]:
                restaurants.append(r)

        logger.info(f"   Radius {radius}m: {len(results)} found (total: {len(restaurants)})")

        if len(restaurants) >= count:
            break  # Found enough

        time.sleep(0.3)  # Brief pause between API calls (be nice to servers)

    if not restaurants:
        logger.warning("   No restaurants found")
        return []

    # Enrich restaurants with pricing, distance, etc.
    restaurants = _enrich_restaurants(restaurants, city, country, budget_level, meal_type, lat, lon)

    # Sort by distance (nearest first)
    restaurants.sort(key=lambda x: x.get('distance_km', 999))

    # Filter out already-used restaurants
    available = [r for r in restaurants if r['osm_id'] not in used_osm_ids]

    logger.info(f"✅ Returning {min(len(available), count)} restaurants")
    return available[:count]


def _fetch_restaurants(lat: float, lon: float, radius: int, meal_type: str) -> List[Dict]:
    """
    Query OpenStreetMap for restaurants near a location

    Uses Overpass API - a query language for OSM data

    Args:
        lat, lon: Center point
        radius: Search radius in meters
        meal_type: Type of meal to search for

    Returns:
        Raw list of restaurants from OSM

    Query logic:
    - Breakfast: Look for cafes, restaurants, bakeries
    - Other meals: Look for restaurants, cafes, fast_food
    """

    # Customize query based on meal type
    if meal_type == 'breakfast':
        amenity = '["amenity"~"cafe|restaurant|bakery"]'
    else:
        amenity = '["amenity"~"restaurant|cafe|fast_food"]'

    # Overpass QL query
    # [out:json] = return JSON
    # node{amenity}["name"] = find nodes with this amenity and a name
    # (around:{radius},{lat},{lon}) = within radius of location
    # out 60 = return max 60 results
    query = f'''
[out:json][timeout:{QUERY_TIMEOUT}];
node{amenity}["name"](around:{radius},{lat},{lon});
out 60;
'''

    restaurants = []

    # Try each server until one works
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

                # Parse each result
                for el in elements:
                    r = _parse_restaurant(el)
                    if r:
                        restaurants.append(r)

                return restaurants  # Success!

            elif response.status_code in [429, 503, 504]:
                # Server overloaded or rate limited - try next server
                continue

        except requests.exceptions.Timeout:
            continue  # Server too slow - try next
        except Exception:
            continue  # Any other error - try next

    return restaurants  # Return whatever we got (might be empty)


def _parse_restaurant(el: Dict) -> Dict:
    """
    Convert OpenStreetMap element into our restaurant format

    OSM data structure:
    {
      "id": 123456,
      "lat": 35.6812,
      "lon": 139.7671,
      "tags": {
        "name": "Sushi Restaurant",
        "cuisine": "sushi",
        "amenity": "restaurant",
        "phone": "+81-3-1234-5678",
        ...
      }
    }

    Args:
        el: Raw OSM element

    Returns:
        Cleaned restaurant dict, or None if invalid
    """

    try:
        tags = el.get('tags', {})

        # Get name (prefer English name if available)
        name = tags.get('name:en') or tags.get('name')
        if not name or len(name) < 2:
            return None  # Invalid or missing name

        # Get coordinates
        lat = el.get('lat')
        lon = el.get('lon')
        if not lat or not lon:
            return None  # Missing location

        # Get cuisine type
        cuisine = tags.get('cuisine', 'Local')
        if ';' in cuisine:
            cuisine = cuisine.split(';')[0]  # Take first if multiple
        cuisine = cuisine.replace('_', ' ').title()  # Format nicely

        return {
            'osm_id': str(el.get('id', '')),
            'name': name.strip(),
            'cuisine': cuisine,
            'coordinates': {'lat': lat, 'lng': lon},
            'phone': tags.get('phone', ''),
            'website': tags.get('website', ''),
            'opening_hours': tags.get('opening_hours', ''),
            'amenity': tags.get('amenity', ''),
            'tags': tags,  # Keep raw tags for price extraction
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
    """
    Add calculated fields to restaurants:
    - Dynamic pricing (verified or estimated)
    - Distance and travel time
    - Google Maps links
    - Rating (random for now - could integrate real reviews)
    """

    enriched = []

    for r in restaurants:
        try:
            coords = r['coordinates']
            lat, lon = coords['lat'], coords['lng']

            # Calculate distance from current location
            dist = _haversine(current_lat, current_lon, lat, lon)
            # Estimate travel time (assuming 25 km/h + 10 min buffer)
            travel = (dist / 25) * 60 + 10

            # 🆕 DYNAMIC PRICING - Check OSM tags first, then estimate
            price_info = _extract_price_from_osm(
                r.get('tags', {}),
                country,
                budget_level,
                meal_type,
                r.get('amenity', '')
            )

            # Create Google Maps search link
            encoded = quote(f"{r['name']} {city} {country}")
            maps_link = f"https://www.google.com/maps/search/?api=1&query={encoded}"

            enriched.append({
                'osm_id': r['osm_id'],
                'name': r['name'],
                'cuisine': r['cuisine'],
                'coordinates': r['coordinates'],
                'phone': r.get('phone', ''),
                'website': r.get('website', ''),
                'opening_hours': r.get('opening_hours', ''),
                'amenity': r.get('amenity', ''),
                'address': city,
                'distance_km': round(dist, 2),
                'travel_time_minutes': round(travel, 1),
                # 🆕 Dynamic pricing fields
                'cost_myr': price_info['cost_myr'],
                'estimated_cost_myr': price_info['cost_myr'],
                'cost_display': price_info['display'],  # "RM 25 ✓" or "~RM 30"
                'price_verified': price_info['verified'],  # True if from OSM
                'price_source': price_info['source'],  # 'osm_cost_tag', 'cuisine_estimate', etc.
                'price_level': price_info.get('price_level'),  # 'cheap', 'moderate', 'expensive'
                'rating': round(random.uniform(3.8, 4.8), 1),  # Placeholder rating
                'maps_link': maps_link,
                'maps_link_direct': f"https://www.google.com/maps?q={lat},{lon}",
                'data_source': 'OpenStreetMap',
            })

        except Exception:
            continue

    return enriched


def _extract_price_from_osm(tags: Dict, country: str, budget_level: str, meal_type: str, amenity: str) -> Dict:
    """
    🆕 SMART PRICING - Extract or estimate restaurant prices

    Priority order:
    1. Explicit cost tags from OSM (rare but most accurate)
    2. Price level indicators ($, $$, $$$) from OSM
    3. Cuisine-based estimation (sushi = expensive, fast food = cheap)
    4. Budget-level fallback

    Args:
        tags: OSM tags dict
        country: Country name (affects base prices)
        budget_level: User's budget preference
        meal_type: breakfast/lunch/dinner (affects pricing)
        amenity: restaurant/cafe/fast_food (affects pricing)

    Returns:
        {
            cost_myr: 35.50,
            display: "RM 35 ✓",  # ✓ if verified, ~ if estimated
            verified: True,
            source: 'osm_price_level',
            price_level: 'moderate'
        }
    """

    # Get country-specific base prices
    country_lower = country.lower()
    base_prices = DEFAULT_PRICES.copy()
    for key, prices in COUNTRY_BASE_PRICES.items():
        if key in country_lower:
            base_prices = prices
            break

    # Adjust by meal type (breakfast cheaper, dinner more expensive)
    meal_multipliers = {
        'breakfast': 0.6,  # Breakfast 40% cheaper
        'lunch': 1.0,
        'dinner': 1.3,     # Dinner 30% more expensive
        'snack': 0.4,
        'cafe': 0.5,
    }
    meal_mult = meal_multipliers.get(meal_type, 1.0)

    verified = False
    source = 'estimated'
    price_level = None
    cost_myr = None

    # 1. Check for explicit cost tags (rare but best)
    if tags.get('cost') or tags.get('price'):
        cost_str = tags.get('cost') or tags.get('price')
        import re
        numbers = re.findall(r'[\d.]+', str(cost_str))
        if numbers:
            try:
                cost_myr = float(numbers[0])
                # If too small, might be in local currency - convert roughly
                if cost_myr < 5:
                    cost_myr = cost_myr * 4.5  # Rough MYR conversion
                verified = True
                source = 'osm_cost_tag'
            except:
                pass

    # 2. Check for price_level/price_range tags (more common)
    if not verified:
        osm_price = tags.get('price_level') or tags.get('price_range') or tags.get('price')
        if osm_price:
            osm_price_str = str(osm_price).lower()

            # Map various price indicators to our levels
            if osm_price_str in ['$', 'cheap', 'budget', 'low', '1', 'inexpensive']:
                price_level = 'cheap'
                cost_myr = base_prices['cheap'] * meal_mult
                verified = True
                source = 'osm_price_level'
            elif osm_price_str in ['$$', 'moderate', 'medium', 'mid', '2', 'average']:
                price_level = 'moderate'
                cost_myr = base_prices['moderate'] * meal_mult
                verified = True
                source = 'osm_price_level'
            elif osm_price_str in ['$$$', '$$$$', 'expensive', 'high', 'luxury', '3', '4', 'upscale']:
                price_level = 'expensive'
                cost_myr = base_prices['expensive'] * meal_mult
                verified = True
                source = 'osm_price_level'

    # 3. Estimate based on cuisine type and amenity
    if not verified:
        cuisine = tags.get('cuisine', '').lower()

        # Fast food is cheap
        if amenity == 'fast_food' or any(x in cuisine for x in ['fast_food', 'burger', 'pizza', 'kebab', 'sandwich']):
            price_level = 'cheap'
            cost_myr = base_prices['cheap'] * meal_mult * random.uniform(0.8, 1.1)
            source = 'cuisine_fast_food'

        # Street food is very cheap
        elif any(x in cuisine for x in ['street_food', 'hawker', 'food_court']):
            price_level = 'cheap'
            cost_myr = base_prices['cheap'] * meal_mult * random.uniform(0.7, 1.0)
            source = 'cuisine_street_food'

        # Fine dining is expensive
        elif any(x in cuisine for x in ['fine_dining', 'french', 'italian', 'japanese', 'sushi', 'seafood', 'steakhouse']):
            price_level = 'expensive'
            cost_myr = base_prices['expensive'] * meal_mult * random.uniform(0.8, 1.2)
            source = 'cuisine_fine_dining'

        # Asian cuisines are moderate
        elif any(x in cuisine for x in ['chinese', 'thai', 'vietnamese', 'indian', 'korean']):
            price_level = 'moderate'
            cost_myr = base_prices['moderate'] * meal_mult * random.uniform(0.7, 1.1)
            source = 'cuisine_asian'

        # Cafes are cheap
        elif amenity == 'cafe' or 'coffee' in cuisine or 'cafe' in cuisine:
            price_level = 'cheap'
            cost_myr = base_prices['cheap'] * meal_mult * random.uniform(0.8, 1.2)
            source = 'amenity_cafe'

        # Bakeries are cheap
        elif amenity == 'bakery' or 'bakery' in cuisine:
            price_level = 'cheap'
            cost_myr = base_prices['cheap'] * meal_mult * random.uniform(0.5, 0.8)
            source = 'amenity_bakery'

    # 4. Final fallback - use budget level
    if cost_myr is None:
        budget_mult = {'Low': 0.7, 'Medium': 1.0, 'High': 1.5}.get(budget_level, 1.0)
        cost_myr = base_prices['moderate'] * meal_mult * budget_mult * random.uniform(0.85, 1.15)
        price_level = 'moderate'
        source = 'budget_estimate'

    # Round the cost
    cost_myr = round(cost_myr, 2)

    # Create display string
    if verified:
        display = f"RM {cost_myr:.0f} ✓"  # Checkmark = verified from OSM
    else:
        display = f"~RM {cost_myr:.0f}"   # Tilde = estimated

    return {
        'cost_myr': cost_myr,
        'display': display,
        'verified': verified,
        'source': source,
        'price_level': price_level,
    }


def _haversine(lat1: float, lon1: float, lat2: float, lon2: float) -> float:
    """
    Calculate distance between two points on Earth
    Same Haversine formula as in route_optimizer.py
    Returns distance in kilometers
    """
    from math import radians, cos, sin, asin, sqrt
    lat1, lon1, lat2, lon2 = map(radians, [lat1, lon1, lat2, lon2])
    dlat, dlon = lat2 - lat1, lon2 - lon1
    a = sin(dlat/2)**2 + cos(lat1) * cos(lat2) * sin(dlon/2)**2
    return 2 * asin(sqrt(a)) * 6371  # Earth radius = 6371 km