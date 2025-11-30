"""
ML RECOMMENDATION HELPER FOR CLOUD FUNCTION
=============================================
Add this file to your Cloud Functions folder (functions/python/)
and import it in your main.py

This module reads pre-computed ML scores from Firestore and
adds them to itinerary items.

Usage in your generateCompleteTrip function:
    from ml_helper import get_ml_recommendations, add_ml_score_to_item

"""

from firebase_admin import firestore
import logging

logger = logging.getLogger(__name__)

def get_firestore_client():
    """Get Firestore client"""
    return firestore.client()


def get_ml_score(db, user_id: str, destination_id: str) -> float:
    """
    Get pre-computed ML score for a user-destination pair.

    Args:
        db: Firestore client
        user_id: User ID
        destination_id: Destination ID

    Returns:
        ML score (0-1) or 0.5 as default
    """
    try:
        doc_id = f"{user_id}_{destination_id}"
        doc = db.collection('mlPredictions').document(doc_id).get()

        if doc.exists:
            score = doc.to_dict().get('mlScore', 0.5)
            logger.info(f"ML score for {destination_id}: {score:.3f}")
            return float(score)
        else:
            logger.debug(f"No ML score found for {doc_id}, using default")
            return 0.5

    except Exception as e:
        logger.warning(f"Error getting ML score: {e}")
        return 0.5


def get_ml_recommendations(db, user_id: str, city: str = None, country: str = None,
                           category: str = None, limit: int = 50) -> list:
    """
    Get ranked ML recommendations for a user.

    Args:
        db: Firestore client
        user_id: User ID
        city: Optional city filter
        country: Optional country filter
        category: Optional category filter
        limit: Max number of results

    Returns:
        List of destinations sorted by ML score (highest first)
    """
    try:
        query = db.collection('mlPredictions').where('userID', '==', user_id)

        # Note: Firestore doesn't support multiple inequality filters
        # So we filter in Python after fetching

        docs = list(query.stream())

        recommendations = []
        for doc in docs:
            data = doc.to_dict()

            # Apply filters
            if city and data.get('city', '').lower() != city.lower():
                continue
            if country and data.get('country', '').lower() != country.lower():
                continue
            if category and data.get('category', '').lower() != category.lower():
                continue

            recommendations.append({
                'destinationID': data.get('destinationID'),
                'destinationName': data.get('destinationName'),
                'category': data.get('category'),
                'city': data.get('city'),
                'country': data.get('country'),
                'mlScore': data.get('mlScore', 0.5),
            })

        # Sort by ML score descending
        recommendations.sort(key=lambda x: x['mlScore'], reverse=True)

        logger.info(f"Found {len(recommendations)} ML recommendations for user {user_id[:20]}...")

        return recommendations[:limit]

    except Exception as e:
        logger.error(f"Error getting ML recommendations: {e}")
        return []


def get_user_preferred_categories(db, user_id: str) -> list:
    """
    Get user's preferred categories based on interactions.

    Args:
        db: Firestore client
        user_id: User ID

    Returns:
        List of preferred category names
    """
    try:
        # Get user's positive interactions
        interactions = db.collection('userInteractions')\
            .where('userID', '==', user_id)\
            .where('interactionType', 'in', ['add_to_trip', 'save'])\
            .stream()

        # Count categories
        category_counts = {}
        for doc in interactions:
            cat = doc.to_dict().get('category', 'attraction')
            category_counts[cat] = category_counts.get(cat, 0) + 1

        # Sort by count
        sorted_cats = sorted(category_counts.items(), key=lambda x: x[1], reverse=True)

        return [cat for cat, count in sorted_cats[:5]]

    except Exception as e:
        logger.warning(f"Error getting preferred categories: {e}")
        return ['attraction', 'cultural', 'museum']


def add_ml_score_to_item(db, user_id: str, item: dict) -> dict:
    """
    Add ML score to an itinerary item.

    Args:
        db: Firestore client
        user_id: User ID
        item: Itinerary item dict (must have 'locationID' or 'destinationID')

    Returns:
        Item with 'mlScore' added
    """
    dest_id = item.get('locationID') or item.get('destinationID') or item.get('id')

    if dest_id:
        item['mlScore'] = get_ml_score(db, user_id, dest_id)
    else:
        item['mlScore'] = 0.5

    return item


def rank_destinations_by_ml(db, user_id: str, destinations: list) -> list:
    """
    Rank a list of destinations by ML score for a user.

    Args:
        db: Firestore client
        user_id: User ID
        destinations: List of destination dicts

    Returns:
        Same list sorted by ML score (highest first)
    """
    for dest in destinations:
        dest_id = dest.get('id') or dest.get('osm_id')
        dest['mlScore'] = get_ml_score(db, user_id, dest_id)

        # Mark if this matches user preferences
        dest['is_ml_recommended'] = dest['mlScore'] > 0.6

    # Sort by ML score
    destinations.sort(key=lambda x: x.get('mlScore', 0), reverse=True)

    return destinations


# ============================================================
# COLD START HANDLING
# ============================================================

def get_cold_start_recommendations(db, city: str = None, country: str = None,
                                    category: str = None, limit: int = 20) -> list:
    """
    Get popular recommendations for new users (cold start).

    Args:
        db: Firestore client
        city: Optional city filter
        country: Optional country filter
        category: Optional category filter
        limit: Max results

    Returns:
        List of popular destinations
    """
    try:
        # Try to load cold start recs from storage
        # Fallback to querying popular destinations

        query = db.collection('destinationData')

        if city:
            query = query.where('city', '==', city)
        if country:
            query = query.where('country', '==', country)
        if category:
            query = query.where('category', '==', category)

        docs = list(query.limit(limit * 2).stream())

        destinations = []
        for doc in docs:
            data = doc.to_dict()
            destinations.append({
                'id': doc.id,
                'name': data.get('name'),
                'category': data.get('category'),
                'rating': data.get('rating', 4.0),
                'popularity': data.get('popularity', 50),
                'mlScore': 0.5,  # Default score for cold start
            })

        # Sort by rating/popularity
        destinations.sort(key=lambda x: (x.get('rating', 0), x.get('popularity', 0)), reverse=True)

        return destinations[:limit]

    except Exception as e:
        logger.error(f"Error getting cold start recommendations: {e}")
        return []


def is_cold_start_user(db, user_id: str) -> bool:
    """
    Check if user has no interaction history (cold start).

    Args:
        db: Firestore client
        user_id: User ID

    Returns:
        True if user has no interactions
    """
    try:
        interactions = db.collection('userInteractions')\
            .where('userID', '==', user_id)\
            .limit(1)\
            .stream()

        return len(list(interactions)) == 0

    except Exception as e:
        logger.warning(f"Error checking cold start: {e}")
        return True  # Assume cold start on error