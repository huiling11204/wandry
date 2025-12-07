"""
ML Recommendation Helper - Gets personalized suggestions from your ML model

SIMPLE EXPLANATION:
- My ML model pre-computes "scores" for each user-destination pair
- Scores stored in Firestore collection 'mlPredictions'
- This helper reads those scores and ranks destinations
- Higher score = better match for user's preferences

EXAMPLE WORKFLOW:
1. ML model trains offline → generates scores
2. Scores saved to Firestore: {userID: 'user123', destinationID: 'dest456', mlScore: 0.85}
3. This helper retrieves those scores when building itineraries

WHY PRE-COMPUTE?
- ML models are slow (seconds to minutes)
- Pre-computing lets us retrieve scores instantly
- Scores can be updated periodically (daily/weekly)
"""

from firebase_admin import firestore
import logging

logger = logging.getLogger(__name__)

def get_firestore_client():
    """Get Firestore database connection"""
    return firestore.client()


def get_ml_score(db, user_id: str, destination_id: str) -> float:
    """
    Get the ML recommendation score for a specific user-destination pair

    Args:
        db: Firestore database client
        user_id: The user's ID (e.g., 'user_abc123')
        destination_id: The destination's ID (e.g., 'tokyo_tower')

    Returns:
        ML score between 0 and 1
        - 0.8-1.0 = Strong recommendation (user will likely love this)
        - 0.5-0.8 = Moderate recommendation
        - 0.0-0.5 = Weak recommendation
        - 0.5 = Default (no data available)

    How it works:
    1. Creates lookup key: "user_abc123_tokyo_tower"
    2. Checks Firestore collection 'mlPredictions' for this document
    3. Returns the mlScore field, or 0.5 if not found
    """
    try:
        # Create document ID by combining user and destination IDs
        doc_id = f"{user_id}_{destination_id}"

        # Look up the pre-computed score
        doc = db.collection('mlPredictions').document(doc_id).get()

        if doc.exists:
            score = doc.to_dict().get('mlScore', 0.5)
            logger.info(f"ML score for {destination_id}: {score:.3f}")
            return float(score)
        else:
            # No score found - return neutral default
            logger.debug(f"No ML score found for {doc_id}, using default")
            return 0.5

    except Exception as e:
        logger.warning(f"Error getting ML score: {e}")
        return 0.5  # Safe default on error


def get_ml_recommendations(db, user_id: str, city: str = None, country: str = None,
                           category: str = None, limit: int = 50) -> list:
    """
    Get top ML recommendations for a user with optional filters

    Args:
        db: Firestore client
        user_id: User's ID
        city: Optional - only get recommendations in this city (e.g., 'Tokyo')
        country: Optional - only get recommendations in this country (e.g., 'Japan')
        category: Optional - only get recommendations of this type (e.g., 'museum')
        limit: Max number of results to return

    Returns:
        List of recommendations sorted by ML score (best first)
        Each recommendation includes:
        - destinationID, destinationName
        - category, city, country
        - mlScore (0-1)

    Example:
        get_ml_recommendations(db, 'user123', city='Tokyo', category='museum', limit=10)
        → Top 10 museums in Tokyo for this user

    Note: Filters are applied in Python (not Firestore query)
          because Firestore limits complex queries
    """
    try:
        # Start with query for this user
        query = db.collection('mlPredictions').where('userID', '==', user_id)

        # Note: Can't filter by multiple fields in Firestore query
        # We'll filter in Python after retrieving

        docs = list(query.stream())

        recommendations = []
        for doc in docs:
            data = doc.to_dict()

            # Apply filters in Python
            if city and data.get('city', '').lower() != city.lower():
                continue  # Skip if city doesn't match
            if country and data.get('country', '').lower() != country.lower():
                continue
            if category and data.get('category', '').lower() != category.lower():
                continue

            # Add to results
            recommendations.append({
                'destinationID': data.get('destinationID'),
                'destinationName': data.get('destinationName'),
                'category': data.get('category'),
                'city': data.get('city'),
                'country': data.get('country'),
                'mlScore': data.get('mlScore', 0.5),
            })

        # Sort by ML score (highest first)
        recommendations.sort(key=lambda x: x['mlScore'], reverse=True)

        logger.info(f"Found {len(recommendations)} ML recommendations for user {user_id[:20]}...")

        return recommendations[:limit]

    except Exception as e:
        logger.error(f"Error getting ML recommendations: {e}")
        return []


def get_user_preferred_categories(db, user_id: str) -> list:
    """
    Figure out what types of places a user likes

    Looks at user's past behavior:
    - What they added to trips
    - What they saved/favorited
    - Counts which categories appear most

    Args:
        db: Firestore client
        user_id: User's ID

    Returns:
        List of category names user likes, sorted by preference
        Example: ['museum', 'cultural', 'park', 'restaurant', 'shopping']

    Used for:
    - Personalizing recommendations
    - Understanding user preferences
    - Cold start (when we don't have ML scores yet)
    """
    try:
        # Get user's positive interactions (things they liked)
        interactions = db.collection('userInteractions')\
            .where('userID', '==', user_id)\
            .where('interactionType', 'in', ['add_to_trip', 'save'])\
            .stream()

        # Count how many times each category appears
        category_counts = {}
        for doc in interactions:
            cat = doc.to_dict().get('category', 'attraction')
            category_counts[cat] = category_counts.get(cat, 0) + 1

        # Sort by count (most popular first)
        sorted_cats = sorted(category_counts.items(), key=lambda x: x[1], reverse=True)

        # Return top 5 categories
        return [cat for cat, count in sorted_cats[:5]]

    except Exception as e:
        logger.warning(f"Error getting preferred categories: {e}")
        # Safe defaults
        return ['attraction', 'cultural', 'museum']


def add_ml_score_to_item(db, user_id: str, item: dict) -> dict:
    """
    Add ML score to a single itinerary item

    Args:
        db: Firestore client
        user_id: User's ID
        item: Dictionary representing a destination
              Should have one of: 'locationID', 'destinationID', or 'id'

    Returns:
        Same item dictionary with 'mlScore' field added

    Example:
        item = {name: 'Tokyo Tower', locationID: 'tower123'}
        add_ml_score_to_item(db, 'user456', item)
        → {name: 'Tokyo Tower', locationID: 'tower123', mlScore: 0.85}
    """
    # Find the destination ID (might be stored under different field names)
    dest_id = item.get('locationID') or item.get('destinationID') or item.get('id')

    if dest_id:
        item['mlScore'] = get_ml_score(db, user_id, dest_id)
    else:
        item['mlScore'] = 0.5  # No ID found, use default

    return item


def rank_destinations_by_ml(db, user_id: str, destinations: list) -> list:
    """
    Sort a list of destinations by how well they match user preferences

    Args:
        db: Firestore client
        user_id: User's ID
        destinations: List of destination dicts

    Returns:
        Same list, sorted by ML score (best matches first)
        Also adds 'mlScore' and 'is_ml_recommended' fields

    Example:
        destinations = [{name: 'Museum A'}, {name: 'Park B'}, {name: 'Museum C'}]
        ranked = rank_destinations_by_ml(db, 'user123', destinations)
        → If user loves museums: [{Museum A, score: 0.9}, {Museum C, score: 0.85}, {Park B, score: 0.6}]
    """
    for dest in destinations:
        # Get destination ID (might be stored as 'id' or 'osm_id')
        dest_id = dest.get('id') or dest.get('osm_id')
        dest['mlScore'] = get_ml_score(db, user_id, dest_id)

        # Mark strong recommendations
        dest['is_ml_recommended'] = dest['mlScore'] > 0.6

    # Sort by ML score (highest first)
    destinations.sort(key=lambda x: x.get('mlScore', 0), reverse=True)

    return destinations


# ============================================================
# COLD START HANDLING
# ============================================================

def get_cold_start_recommendations(db, city: str = None, country: str = None,
                                    category: str = None, limit: int = 20) -> list:
    """
    Get recommendations for NEW USERS (who have no history)

    "Cold start problem":
    - New users have no interaction history
    - ML model has no data to personalize
    - Solution: Show popular destinations everyone likes

    Args:
        db: Firestore client
        city, country, category: Optional filters
        limit: Max results

    Returns:
        List of popular destinations
        Based on: high ratings, popularity scores

    This ensures new users still get good recommendations!
    """
    try:
        # Query general destination database
        query = db.collection('destinationData')

        # Apply filters if provided
        if city:
            query = query.where('city', '==', city)
        if country:
            query = query.where('country', '==', country)
        if category:
            query = query.where('category', '==', category)

        # Get more than we need (we'll filter/sort)
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
                'mlScore': 0.5,  # Neutral score (no personalization)
            })

        # Sort by rating and popularity (best first)
        destinations.sort(key=lambda x: (x.get('rating', 0), x.get('popularity', 0)), reverse=True)

        return destinations[:limit]

    except Exception as e:
        logger.error(f"Error getting cold start recommendations: {e}")
        return []


def is_cold_start_user(db, user_id: str) -> bool:
    """
    Check if user is new (has no interaction history)

    Args:
        db: Firestore client
        user_id: User's ID

    Returns:
        True if user has no interactions (is new)
        False if user has history

    Used to decide:
    - Show personalized recommendations? (if False)
    - Show popular recommendations? (if True)
    """
    try:
        # Check if user has ANY interactions
        interactions = db.collection('userInteractions')\
            .where('userID', '==', user_id)\
            .limit(1)\
            .stream()

        has_interactions = len(list(interactions)) > 0
        return not has_interactions  # True if NO interactions

    except Exception as e:
        logger.warning(f"Error checking cold start: {e}")
        return True  # Assume cold start on error (safer)