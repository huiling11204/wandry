"""
Route Optimizer - Arranges destinations to minimize travel distance

SIMPLE EXPLANATION:
- Takes a list of places to visit
- Rearranges them so you travel the shortest total distance
- Uses "nearest neighbor" algorithm (always go to closest unvisited place)
- Calculates distances using Haversine formula (accounts for Earth's curvature)

EXAMPLE:
Input: [Tokyo Tower, Shibuya, Asakusa, Shinjuku]
Output: [Tokyo Tower, Shinjuku, Shibuya, Asakusa] (optimized order)
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
    Rearrange destinations to minimize total travel distance

    Args:
        destinations: List of places with coordinates
                     Each dict should have: {coordinates: {lat: X, lng: Y}, ...}
        start_location: Optional starting point (lat, lng)
                       If None, starts from first destination

    Returns:
        Same list of destinations, but reordered for efficiency

    Algorithm: "Greedy Nearest Neighbor"
    1. Start at starting location
    2. Always visit the closest unvisited place next
    3. Repeat until all places visited

    Note: This gives a good (but not perfect) solution quickly
    Perfect solution requires checking all possibilities (very slow)
    """

    # Edge cases
    if not destinations:
        return []

    if len(destinations) <= 2:
        return destinations  # No point optimizing 1-2 destinations

    try:
        # Step 1: Extract coordinates from each destination
        coords = []
        for dest in destinations:
            if 'coordinates' in dest:
                lat = dest['coordinates'].get('lat')
                lng = dest['coordinates'].get('lng')
                if lat and lng:
                    coords.append((lat, lng))
                else:
                    coords.append(None)  # Missing coordinates
            else:
                coords.append(None)

        # Step 2: Check if we have coordinates for all destinations
        valid_coords = [c for c in coords if c is not None]
        if len(valid_coords) < len(destinations):
            logger.warning("Some destinations missing coordinates, skipping optimization")
            return destinations  # Can't optimize without coordinates

        # Step 3: Set starting point
        if start_location:
            current = start_location  # User-provided start
        else:
            current = coords[0]  # Start from first destination

        # Step 4: Greedy algorithm - always visit nearest unvisited place
        optimized_indices = []  # Will hold the optimized order (as indices)
        remaining_indices = list(range(len(destinations)))  # Indices of unvisited places

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

            # Visit this place
            optimized_indices.append(nearest_idx)
            remaining_indices.remove(nearest_idx)
            current = coords[nearest_idx]  # Update current location

        # Step 5: Reorder destinations according to optimized indices
        optimized_destinations = [destinations[i] for i in optimized_indices]

        # Step 6: Calculate how much distance we saved
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
        # If optimization fails, return original order
        return destinations


def _calculate_distance(lat1: float, lon1: float, lat2: float, lon2: float) -> float:
    """
    Calculate distance between two points on Earth

    Uses Haversine formula - accounts for Earth's spherical shape
    More accurate than simple straight-line distance

    Args:
        lat1, lon1: First point (latitude, longitude in degrees)
        lat2, lon2: Second point

    Returns:
        Distance in kilometers

    Example:
        Distance from Tokyo to Osaka ≈ 400km
    """
    from math import radians, cos, sin, asin, sqrt

    # Convert degrees to radians (required for trig functions)
    lat1, lon1, lat2, lon2 = map(radians, [lat1, lon1, lat2, lon2])

    # Haversine formula
    # This accounts for the curvature of the Earth
    dlat = lat2 - lat1  # Difference in latitude
    dlon = lon2 - lon1  # Difference in longitude

    # The formula (looks complex but handles spherical geometry)
    a = sin(dlat/2)**2 + cos(lat1) * cos(lat2) * sin(dlon/2)**2
    c = 2 * asin(sqrt(a))

    # Earth radius in kilometers
    r = 6371

    return c * r


def _calculate_total_distance(destinations: List[Dict]) -> float:
    """
    Calculate total distance for a complete route

    Sums up distances between consecutive destinations:
    Distance = A→B + B→C + C→D + ...

    Args:
        destinations: Ordered list of places

    Returns:
        Total distance in kilometers
    """
    if len(destinations) < 2:
        return 0.0

    total = 0.0

    # Add up distance between each consecutive pair
    for i in range(len(destinations) - 1):
        coords1 = destinations[i].get('coordinates', {})
        coords2 = destinations[i + 1].get('coordinates', {})

        lat1 = coords1.get('lat')
        lng1 = coords1.get('lng')
        lat2 = coords2.get('lat')
        lng2 = coords2.get('lng')

        # Only add if both destinations have coordinates
        if all([lat1, lng1, lat2, lng2]):
            total += _calculate_distance(lat1, lng1, lat2, lng2)

    return total


def calculate_travel_time(distance_km: float, mode: str = 'walking') -> float:
    """
    Estimate travel time based on distance and transportation mode

    Args:
        distance_km: Distance in kilometers
        mode: How you're traveling ('walking', 'driving', 'transit', 'bicycle')

    Returns:
        Estimated travel time in minutes (includes 10 min buffer)

    Example:
        5km walking = 5/5 * 60 + 10 = 70 minutes
    """

    # Average speeds in km/h (conservative estimates for city travel)
    speeds = {
        'walking': 5,      # 5 km/h - leisurely walking pace
        'driving': 30,     # 30 km/h - city driving with traffic
        'transit': 25,     # 25 km/h - trains/buses with stops
        'bicycle': 15,     # 15 km/h - casual cycling
    }

    speed = speeds.get(mode, speeds['walking'])

    # Calculate time: time = distance / speed
    time_hours = distance_km / speed

    # Convert to minutes and add safety buffer
    time_minutes = time_hours * 60
    buffer = 10  # Extra 10 minutes for getting around, waiting, etc.

    return time_minutes + buffer


def get_route_summary(destinations: List[Dict]) -> Dict:
    """
    Get useful statistics about a route

    Args:
        destinations: List of places in order

    Returns:
        Dictionary with:
        - total_distance_km: Total distance to travel
        - total_travel_time_minutes: Estimated walking time
        - num_stops: Number of destinations
        - avg_distance_between_stops: Average distance between places

    Useful for showing users:
    "This route is 15.5km with 4 stops, averaging 3.9km between stops"
    """

    total_distance = _calculate_total_distance(destinations)
    total_time = calculate_travel_time(total_distance, mode='walking')

    return {
        'total_distance_km': round(total_distance, 2),
        'total_travel_time_minutes': round(total_time, 1),
        'num_stops': len(destinations),
        'avg_distance_between_stops': round(total_distance / max(len(destinations) - 1, 1), 2),
    }