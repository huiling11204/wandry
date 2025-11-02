const functions = require('firebase-functions');
const admin = require('firebase-admin');
const axios = require('axios');

admin.initializeApp();

// ============================================
// SEARCH DESTINATIONS - onRequest version
// ============================================
exports.searchDestinations = functions.https.onRequest(async (req, res) => {
  // Enable CORS
  res.set('Access-Control-Allow-Origin', '*');
  res.set('Access-Control-Allow-Methods', 'GET, POST');
  res.set('Access-Control-Allow-Headers', 'Content-Type');

  if (req.method === 'OPTIONS') {
    res.status(204).send('');
    return;
  }

  const { query, limit = 20 } = req.body;

  if (!query?.trim()) {
    res.status(400).json({ success: false, error: 'Query required' });
    return;
  }

  try {
    console.log(`Searching for: ${query}`);

    const response = await axios.get('https://nominatim.openstreetmap.org/search', {
      params: {
        q: query,
        format: 'json',
        limit: limit,
        addressdetails: 1,
      },
      headers: {
        'User-Agent': 'WandryTravelApp/1.0 (wonghl-pm22@student.tarc.edu.my)'
      },
      timeout: 10000,
    });

    console.log(`OpenStreetMap returned ${response.data.length} results`);

    // Log first result to see structure
    if (response.data.length > 0) {
      console.log('First OSM result:', JSON.stringify(response.data[0], null, 2));
    }

    const results = response.data.map(place => {
      const result = {
        placeId: place.place_id,
        osmType: place.osm_type,
        osmId: place.osm_id,
        name: place.display_name,
        latitude: parseFloat(place.lat),
        longitude: parseFloat(place.lon),
        type: place.type,
        category: place.class,
        address: {
          city: place.address?.city || place.address?.town || '',
          country: place.address?.country || '',
          state: place.address?.state || '',
        },
      };

      // Log to verify fields are present
      console.log(`Mapped result - osmType: ${result.osmType}, osmId: ${result.osmId}`);

      return result;
    });

    res.json({ success: true, results });

  } catch (error) {
    console.error('Search error:', error.message);
    res.status(500).json({ success: false, error: 'Search failed' });
  }
});

// ============================================
// GET PLACE DETAILS - HTTP version (NEW!)
// ============================================
exports.getPlaceDetailsHTTP = functions.https.onRequest(async (req, res) => {
  // Enable CORS
  res.set('Access-Control-Allow-Origin', '*');
  res.set('Access-Control-Allow-Methods', 'GET, POST');
  res.set('Access-Control-Allow-Headers', 'Content-Type');

  if (req.method === 'OPTIONS') {
    res.status(204).send('');
    return;
  }

  const { osmType, osmId, latitude, longitude } = req.body;

  console.log('📥 HTTP Received:', { osmType, osmId, osmIdType: typeof osmId });

  if (!osmType || osmType === '') {
    res.status(400).json({ success: false, error: 'Missing osmType' });
    return;
  }

  if (osmId === null || osmId === undefined || osmId === '') {
    res.status(400).json({ success: false, error: 'Missing osmId' });
    return;
  }

  try {
    const osmIdStr = String(osmId);
    const overpassQuery = `[out:json];${osmType}(${osmIdStr});out body;`;

    console.log('🔍 Query:', overpassQuery);

    const response = await axios.post(
      'https://overpass-api.de/api/interpreter',
      overpassQuery,
      {
        headers: {
          'Content-Type': 'text/plain',
          'User-Agent': 'WandryTravelApp/1.0'
        },
        timeout: 30000
      }
    );

    const place = response.data.elements?.[0];
    if (!place) {
      res.json({
        success: true,
        details: {
          name: 'Unknown',
          description: 'No details available',
          openingHours: 'Not available',
          phone: 'Not available',
          website: '',
          latitude: latitude || 0,
          longitude: longitude || 0,
        }
      });
      return;
    }

    const tags = place.tags || {};
    const details = {
      name: tags.name || tags['name:en'] || 'Unknown',
      description: tags.description || tags.tourism || tags.amenity || '',
      openingHours: tags.opening_hours || 'Not available',
      phone: tags.phone || tags['contact:phone'] || 'Not available',
      website: tags.website || tags['contact:website'] || '',
      latitude: latitude || place.lat || 0,
      longitude: longitude || place.lon || 0,
    };

    console.log('✅ Returning:', details.name);
    res.json({ success: true, details });

  } catch (error) {
    console.error('❌ Error:', error.message);
    res.json({
      success: true,
      details: {
        name: 'Unknown',
        description: 'Error fetching details',
        openingHours: 'Not available',
        phone: 'Not available',
        website: '',
        latitude: latitude || 0,
        longitude: longitude || 0,
      }
    });
  }
});