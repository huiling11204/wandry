"""
Route Optimizer - Optimize daily itinerary routes
Uses simple distance-based optimization (traveling salesman problem approximation)
"""

import logging
from typing import List, Dict, Tuple
import math

logger = logging.getLogger(__name__)


def optimize_daily_route(
    destinations: List[Dict],
    start_location: Tuple[float, float] = None
) -> List[Dict]:
    """
    Optimize the order of destinations to minimize travel distance

    Args:
        destinations: List of destination dictionaries with coordinates
        start_location: Optional starting point (lat, lng) - uses first destination if None

    Returns:
        Optimized list of destinations
    """

    if not destinations:
        return []

    if len(destinations) <= 2:
        return destinations

    try:
        # Extract coordinates
        coords = []
        for dest in destinations:
            if 'coordinates' in dest:
                lat = dest['coordinates'].get('lat')
                lng = dest['coordinates'].get('lng')
                if lat and lng:
                    coords.append((lat, lng))
                else:
                    coords.append(None)
            else:
                coords.append(None)

        # If we don't have valid coordinates for optimization, return as-is
        valid_coords = [c for c in coords if c is not None]
        if len(valid_coords) < len(destinations):
            logger.warning("Some destinations missing coordinates, skipping optimization")
            return destinations

        # Start from the specified location or first destination
        if start_location:
            current = start_location
        else:
            current = coords[0]

        optimized_indices = []
        remaining_indices = list(range(len(destinations)))

        # Greedy nearest-neighbor algorithm
        while remaining_indices:
            if not optimized_indices:
                # First destination
                if start_location:
                    # Find nearest to start location
                    nearest_idx = min(
                        remaining_indices,
                        key=lambda i: _calculate_distance(current[0], current[1], coords[i][0], coords[i][1])
                    )
                else:
                    # Start with first destination
                    nearest_idx = remaining_indices[0]
            else:
                # Find nearest to current location
                nearest_idx = min(
                    remaining_indices,
                    key=lambda i: _calculate_distance(current[0], current[1], coords[i][0], coords[i][1])
                )

            optimized_indices.append(nearest_idx)
            remaining_indices.remove(nearest_idx)
            current = coords[nearest_idx]

        # Reorder destinations
        optimized_destinations = [destinations[i] for i in optimized_indices]

        # Calculate total distance saved
        original_distance = _calculate_total_distance(destinations)
        optimized_distance = _calculate_total_distance(optimized_destinations)
        distance_saved = original_distance - optimized_distance

        logger.info(
            f"Route optimized: {original_distance:.2f}km → {optimized_distance:.2f}km "
            f"(saved {distance_saved:.2f}km)"
        )

        return optimized_destinations

    except Exception as e:
        logger.error(f"Route optimization error: {e}")
        # Return original order if optimization fails
        return destinations


def _calculate_distance(lat1: float, lon1: float, lat2: float, lon2: float) -> float:
    """
    Calculate distance between two points using Haversine formula
    Returns distance in kilometers
    """
    from math import radians, cos, sin, asin, sqrt

    # Convert to radians
    lat1, lon1, lat2, lon2 = map(radians, [lat1, lon1, lat2, lon2])

    # Haversine formula
    dlat = lat2 - lat1
    dlon = lon2 - lon1
    a = sin(dlat/2)**2 + cos(lat1) * cos(lat2) * sin(dlon/2)**2
    c = 2 * asin(sqrt(a))

    # Earth radius in kilometers
    r = 6371

    return c * r


def _calculate_total_distance(destinations: List[Dict]) -> float:
    """
    Calculate total distance for a route
    """
    if len(destinations) < 2:
        return 0.0

    total = 0.0
    for i in range(len(destinations) - 1):
        coords1 = destinations[i].get('coordinates', {})
        coords2 = destinations[i + 1].get('coordinates', {})

        lat1 = coords1.get('lat')
        lng1 = coords1.get('lng')
        lat2 = coords2.get('lat')
        lng2 = coords2.get('lng')

        if all([lat1, lng1, lat2, lng2]):
            total += _calculate_distance(lat1, lng1, lat2, lng2)

    return total


def calculate_travel_time(distance_km: float, mode: str = 'walking') -> float:
    """
    Calculate travel time in minutes based on distance and mode

    Args:
        distance_km: Distance in kilometers
        mode: Travel mode ('walking', 'driving', 'transit')

    Returns:
        Travel time in minutes
    """

    # Average speeds in km/h
    speeds = {
        'walking': 5,      # 5 km/h
        'driving': 30,     # 30 km/h in city
        'transit': 25,     # 25 km/h average
        'bicycle': 15,     # 15 km/h
    }

    speed = speeds.get(mode, speeds['walking'])

    # Time in hours
    time_hours = distance_km / speed

    # Convert to minutes and add buffer
    time_minutes = time_hours * 60
    buffer = 10  # 10 minute buffer

    return time_minutes + buffer


def get_route_summary(destinations: List[Dict]) -> Dict:
    """
    Get summary statistics for a route

    Returns:
        Dictionary with total_distance_km, total_travel_time_minutes, num_stops
    """

    total_distance = _calculate_total_distance(destinations)
    total_time = calculate_travel_time(total_distance, mode='walking')

    return {
        'total_distance_km': round(total_distance, 2),
        'total_travel_time_minutes': round(total_time, 1),
        'num_stops': len(destinations),
        'avg_distance_between_stops': round(total_distance / max(len(destinations) - 1, 1), 2),
    }