"""
Weather Service - FIXED VERSION
✅ Proper date format handling (fixes 400 error)
✅ Better error recovery
✅ Falls back to climate estimates if API fails
"""

import requests
import logging
from datetime import datetime, timedelta
from typing import Dict, Optional

logger = logging.getLogger(__name__)

OPEN_METEO_URL = "https://api.open-meteo.com/v1/forecast"

WMO_CODES = {
    0: "Clear sky", 1: "Mainly clear", 2: "Partly cloudy", 3: "Overcast",
    45: "Foggy", 51: "Light drizzle", 61: "Slight rain", 63: "Moderate rain",
    65: "Heavy rain", 80: "Rain showers", 95: "Thunderstorm",
}


def get_weather_forecast(lat: float, lon: float, start_date: str, end_date: str) -> Dict[str, Dict]:
    """Get weather forecast - returns dict with date as key"""

    logger.info(f"🌤️ Weather for ({lat:.4f}, {lon:.4f}): {start_date} to {end_date}")

    try:
        # Parse dates properly
        start = _parse_date(start_date)
        end = _parse_date(end_date)

        if not start or not end:
            logger.warning(f"   Invalid dates: start={start_date}, end={end_date}")
            return _get_climate_estimates(lat, lon, start_date, end_date)

        today = datetime.now().date()
        max_forecast = today + timedelta(days=16)

        # If trip is too far in future, use climate estimates
        if start.date() > max_forecast:
            logger.info("   Trip too far ahead, using climate estimates")
            return _get_climate_estimates(lat, lon, start_date, end_date)

        # Ensure start is not in the past
        if start.date() < today:
            start = datetime.combine(today, datetime.min.time())

        # Format dates as YYYY-MM-DD for API
        api_start = start.strftime('%Y-%m-%d')
        api_end = min(end.date(), max_forecast).strftime('%Y-%m-%d')

        logger.info(f"   API dates: {api_start} to {api_end}")

        # API request
        params = {
            'latitude': round(lat, 4),
            'longitude': round(lon, 4),
            'daily': 'temperature_2m_max,temperature_2m_min,precipitation_probability_max,weathercode,windspeed_10m_max',
            'timezone': 'auto',
            'start_date': api_start,
            'end_date': api_end,
        }

        response = requests.get(OPEN_METEO_URL, params=params, timeout=10)

        if response.status_code == 200:
            weather_data = _parse_response(response.json())
            logger.info(f"✅ Got forecast for {len(weather_data)} days")
            return weather_data
        else:
            logger.warning(f"⚠️ Weather API status {response.status_code}: {response.text[:100]}")
            return _get_climate_estimates(lat, lon, start_date, end_date)

    except Exception as e:
        logger.warning(f"⚠️ Weather error: {e}")
        return _get_climate_estimates(lat, lon, start_date, end_date)


def _parse_date(date_str) -> Optional[datetime]:
    """Parse various date formats including Firestore timestamps"""
    if not date_str:
        return None

    # Handle if it's already a datetime
    if isinstance(date_str, datetime):
        return date_str

    # Convert to string and clean up
    date_str = str(date_str)

    # Handle Firestore Timestamp objects that may be serialized
    if 'Timestamp' in date_str:
        # Extract date from "Timestamp(seconds=1234567890, nanoseconds=0)"
        import re
        match = re.search(r'seconds=(\d+)', date_str)
        if match:
            return datetime.fromtimestamp(int(match.group(1)))

    # Remove timezone info and clean
    date_str = date_str.replace('Z', '').split('+')[0].split('.')[0]

    # Try various formats
    for fmt in ['%Y-%m-%d', '%Y-%m-%dT%H:%M:%S', '%d/%m/%Y', '%Y/%m/%d']:
        try:
            return datetime.strptime(date_str[:19], fmt)
        except:
            continue

    # Try ISO format
    try:
        return datetime.fromisoformat(date_str.split('T')[0])
    except:
        pass

    # Try parsing just the date part
    try:
        parts = date_str[:10].split('-')
        if len(parts) == 3:
            return datetime(int(parts[0]), int(parts[1]), int(parts[2]))
    except:
        pass

    return None


def _parse_response(data: Dict) -> Dict[str, Dict]:
    """Parse Open-Meteo response"""
    weather_data = {}

    daily = data.get('daily', {})
    dates = daily.get('time', [])
    temp_max = daily.get('temperature_2m_max', [])
    temp_min = daily.get('temperature_2m_min', [])
    rain_prob = daily.get('precipitation_probability_max', [])
    codes = daily.get('weathercode', [])
    wind = daily.get('windspeed_10m_max', [])

    for i, date in enumerate(dates):
        if i >= len(temp_max):
            break

        t_max = temp_max[i] or 25
        t_min = temp_min[i] or 20
        code = codes[i] if i < len(codes) else 0

        weather_data[date] = {
            'date': date,
            'temp': round((t_max + t_min) / 2, 1),
            'temp_max': t_max,
            'temp_min': t_min,
            'feels_like': round((t_max + t_min) / 2, 1),
            'rain_probability': rain_prob[i] if i < len(rain_prob) and rain_prob[i] else 0,
            'description': WMO_CODES.get(code, 'Partly cloudy'),
            'weather_code': code,
            'wind_speed': wind[i] if i < len(wind) and wind[i] else 5,
            'humidity': 60,
            'is_forecast': True,
        }

    return weather_data


def _get_climate_estimates(lat: float, lon: float, start_date: str, end_date: str) -> Dict[str, Dict]:
    """Generate climate estimates when forecast unavailable"""

    weather_data = {}

    try:
        start = _parse_date(start_date) or datetime.now()
        end = _parse_date(end_date) or (start + timedelta(days=3))

        current = start
        while current <= end:
            date_str = current.strftime('%Y-%m-%d')
            climate = _get_climate(lat, lon, current.month)

            weather_data[date_str] = {
                'date': date_str,
                'temp': climate['temp'],
                'temp_max': climate['temp'] + 3,
                'temp_min': climate['temp'] - 3,
                'feels_like': climate['temp'],
                'rain_probability': climate['rain'],
                'description': climate['desc'],
                'weather_code': 2,
                'wind_speed': 8,
                'humidity': 65,
                'is_forecast': False,
                'month_name': current.strftime('%B'),
            }
            current += timedelta(days=1)

    except Exception as e:
        logger.warning(f"Climate estimate error: {e}")

    return weather_data


def _get_climate(lat: float, lon: float, month: int) -> Dict:
    """Get typical climate based on location"""

    # Tropical regions (SE Asia, etc)
    if abs(lat) < 25 and 95 < lon < 150:
        return {'temp': 30, 'rain': 60, 'desc': 'Partly cloudy'}

    # East Asia
    if 25 < lat < 45 and 100 < lon < 145:
        if month in [6, 7, 8]:
            return {'temp': 28, 'rain': 50, 'desc': 'Warm'}
        elif month in [12, 1, 2]:
            return {'temp': 5, 'rain': 30, 'desc': 'Cold'}
        return {'temp': 18, 'rain': 40, 'desc': 'Mild'}

    # Default temperate
    if month in [6, 7, 8]:
        return {'temp': 24, 'rain': 30, 'desc': 'Warm'}
    elif month in [12, 1, 2]:
        return {'temp': 8, 'rain': 40, 'desc': 'Cool'}
    return {'temp': 16, 'rain': 35, 'desc': 'Mild'}