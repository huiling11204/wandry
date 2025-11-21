"""
Destination Service - Find nearby attractions
Better categorization and Google Maps links
"""

import requests
import time
import logging
from typing import List, Dict
import random
import hashlib

logger = logging.getLogger(__name__)


def get_destinations_near_location(
    city: str,
    country: str,
    lat: float,
    lon: float,
    count: int = 100
) -> List[Dict]:
    """
    Get real destinations from OpenStreetMap near a specific location

    IMPROVED: Better Google Maps links, diverse categories
    """

    logger.info(f"🔍 Searching destinations near {lat},{lon}")

    destinations = []

    try:
        overpass_url = "https://overpass-api.de/api/interpreter"
        search_radius = 10000  # 10km

        # Comprehensive query for various attraction types
        query = f"""
        [out:json][timeout:45];
        (
          // Tourist attractions
          node["tourism"~"attraction|museum|gallery|viewpoint|theme_park|zoo|aquarium|artwork"](around:{search_radius},{lat},{lon});
          way["tourism"~"attraction|museum|gallery|viewpoint|theme_park|zoo|aquarium"](around:{search_radius},{lat},{lon});

          // Historical & cultural
          node["historic"~"castle|monument|memorial|archaeological_site|ruins|fort|palace"](around:{search_radius},{lat},{lon});
          way["historic"~"castle|monument|memorial|archaeological_site|ruins|fort|palace"](around:{search_radius},{lat},{lon});

          // Nature & parks
          node["leisure"~"park|garden|nature_reserve"](around:{search_radius},{lat},{lon});
          way["leisure"~"park|garden|nature_reserve"](around:{search_radius},{lat},{lon});

          // Places of worship (temples, shrines, churches)
          node["amenity"="place_of_worship"]["religion"](around:{search_radius},{lat},{lon});
          way["amenity"="place_of_worship"]["religion"](around:{search_radius},{lat},{lon});

          // Shopping & markets
          node["shop"="mall"](around:{search_radius},{lat},{lon});
          way["shop"="mall"](around:{search_radius},{lat},{lon});
          node["amenity"="marketplace"](around:{search_radius},{lat},{lon});

          // Entertainment
          node["amenity"~"theatre|cinema|arts_centre"](around:{search_radius},{lat},{lon});
          way["amenity"~"theatre|cinema|arts_centre"](around:{search_radius},{lat},{lon});
        );
        out center 150;
        """

        response = requests.post(overpass_url, data={'data': query}, timeout=60)

        if response.status_code == 200:
            data = response.json()
            elements = data.get('elements', [])

            logger.info(f"🏛️ Found {len(elements)} potential destinations")

            for element in elements:
                try:
                    osm_id = str(element.get('id', ''))
                    tags = element.get('tags', {})

                    # Get name - prefer English
                    name = tags.get('name:en') or tags.get('name') or tags.get('official_name')
                    if not name or len(name) < 3:
                        continue

                    # Get coordinates
                    if element.get('type') == 'node':
                        dest_lat = element.get('lat')
                        dest_lon = element.get('lon')
                    else:
                        center = element.get('center', {})
                        dest_lat = center.get('lat')
                        dest_lon = center.get('lon')

                    if not dest_lat or not dest_lon:
                        continue

                    # Determine category
                    category = _determine_category(tags)

                    # Get address
                    address = _build_address(tags, city, country)

                    # Contact info
                    phone = tags.get('phone', tags.get('contact:phone', ''))
                    website = tags.get('website', tags.get('contact:website', ''))

                    # Opening hours
                    opening_hours = tags.get('opening_hours', 'Check official website')

                    # Check if outdoor
                    is_outdoor = category in ['park', 'nature', 'cultural', 'temple']

                    # Calculate distance
                    distance_km = _calculate_distance(lat, lon, dest_lat, dest_lon)

                    # Estimate entrance fee
                    estimated_fee = _estimate_entrance_fee(category, country)

                    # Generate unique ID
                    dest_id = hashlib.md5(f"{osm_id}_{name}_{city}".encode()).hexdigest()[:16]

                    # IMPROVED: Better Google Maps link
                    encoded_name = requests.utils.quote(name)
                    maps_link = f"https://www.google.com/maps/search/?api=1&query={encoded_name}+{dest_lat},{dest_lon}"

                    destination = {
                        'id': dest_id,
                        'osm_id': osm_id,
                        'name': name,
                        'city': city,
                        'country': country,
                        'category': category,
                        'rating': round(random.uniform(4.0, 4.8), 1),
                        'popularity': round(random.uniform(3.8, 4.8), 1),
                        'duration_hours': 2.0,
                        'avg_cost': estimated_fee,
                        'description': tags.get('description') or _generate_description(name, category),
                        'opening_hours': opening_hours,
                        'best_time_to_visit': 'Morning (09:00-11:00)',
                        'tips': _generate_tips(category),
                        'facilities': _generate_facilities(tags),
                        'is_outdoor': is_outdoor,
                        'highlights': [name],
                        'accessibility': tags.get('wheelchair', 'Check on arrival'),
                        'address': address,
                        'phone': phone,
                        'website': website,
                        'coordinates': {
                            'lat': dest_lat,
                            'lng': dest_lon
                        },
                        'distance_km': round(distance_km, 2),
                        'maps_link': maps_link,
                        'osm_link': f"https://www.openstreetmap.org/{element.get('type', 'node')}/{osm_id}",
                        'data_source': 'OpenStreetMap',
                    }

                    destinations.append(destination)

                except Exception as e:
                    logger.warning(f"Error processing destination: {e}")
                    continue

        time.sleep(2)

    except Exception as e:
        logger.error(f"❌ Destination search error: {e}")

    # Sort by distance
    destinations.sort(key=lambda x: x['distance_km'])

    logger.info(f"✅ Returning {len(destinations)} destinations")
    return destinations[:count]


def _determine_category(tags: Dict) -> str:
    """Determine destination category from OSM tags"""

    if tags.get('tourism') == 'museum':
        return 'museum'
    elif tags.get('tourism') in ['theme_park', 'zoo', 'aquarium']:
        return 'entertainment'
    elif tags.get('tourism') == 'viewpoint':
        return 'viewpoint'
    elif tags.get('leisure') in ['park', 'garden']:
        return 'park'
    elif tags.get('leisure') == 'nature_reserve':
        return 'nature'
    elif tags.get('historic'):
        return 'cultural'
    elif tags.get('amenity') == 'place_of_worship':
        return 'temple'
    elif tags.get('shop') == 'mall' or tags.get('amenity') == 'marketplace':
        return 'shopping'
    elif tags.get('amenity') in ['theatre', 'cinema', 'arts_centre']:
        return 'entertainment'
    else:
        return 'attraction'


def _build_address(tags: Dict, city: str, country: str) -> str:
    """Build address from OSM tags"""

    parts = []
    if tags.get('addr:housenumber') and tags.get('addr:street'):
        parts.append(f"{tags['addr:housenumber']} {tags['addr:street']}")
    elif tags.get('addr:street'):
        parts.append(tags['addr:street'])

    if tags.get('addr:city'):
        parts.append(tags['addr:city'])
    elif city:
        parts.append(city)

    return ', '.join(parts) if parts else f"{city}, {country}"


def _estimate_entrance_fee(category: str, country: str) -> float:
    """Estimate entrance fee in MYR"""

    multipliers = {
        'Japan': 2.5, 'USA': 2.8, 'Thailand': 0.9,
        'Singapore': 2.4, 'Malaysia': 1.0,
    }

    base_fees = {
        'museum': 25, 'attraction': 30, 'entertainment': 50,
        'temple': 10, 'cultural': 20, 'park': 0,
        'shopping': 0, 'viewpoint': 15, 'nature': 10,
    }

    base = base_fees.get(category, 20)
    multiplier = multipliers.get(country, 1.5)

    return round(base * multiplier * random.uniform(0.8, 1.2), 2)


def _generate_description(name: str, category: str) -> str:
    """Generate a basic description"""
    descriptions = {
        'museum': f"{name} offers a fascinating collection of exhibits and historical artifacts.",
        'park': f"{name} is a beautiful green space perfect for relaxation and outdoor activities.",
        'temple': f"{name} is a significant place of worship with stunning architecture.",
        'cultural': f"{name} is an important historical landmark with rich cultural heritage.",
        'shopping': f"{name} offers a wide variety of shops and dining options.",
        'entertainment': f"{name} provides exciting entertainment for all ages.",
    }
    return descriptions.get(category, f"A popular {category} in the area.")


def _generate_tips(category: str) -> List[str]:
    """Generate helpful tips based on category"""

    tips_map = {
        'museum': ['Book tickets online', 'Visit on weekdays', 'Allow 2-3 hours'],
        'park': ['Best visited in morning', 'Bring water', 'Wear comfortable shoes'],
        'temple': ['Dress modestly', 'Remove shoes', 'Be respectful'],
        'shopping': ['Bargaining is common', 'Cash accepted', 'Peak hours are 2-8 PM'],
    }

    return tips_map.get(category, ['Arrive early', 'Check opening hours'])


def _generate_facilities(tags: Dict) -> List[str]:
    """Extract facilities from tags"""

    facilities = []
    if tags.get('toilets') == 'yes':
        facilities.append('Restrooms')
    if tags.get('wheelchair') == 'yes':
        facilities.append('Wheelchair accessible')
    if tags.get('wifi') == 'yes' or tags.get('internet_access') == 'yes':
        facilities.append('WiFi')
    if not facilities:
        facilities = ['Check on arrival']

    return facilities


def _calculate_distance(lat1: float, lon1: float, lat2: float, lon2: float) -> float:
    """Calculate distance using Haversine formula"""
    from math import radians, cos, sin, asin, sqrt

    lat1, lon1, lat2, lon2 = map(radians, [lat1, lon1, lat2, lon2])
    dlat = lat2 - lat1
    dlon = lon2 - lon1
    a = sin(dlat/2)**2 + cos(lat1) * cos(lat2) * sin(dlon/2)**2
    c = 2 * asin(sqrt(a))
    return c * 6371