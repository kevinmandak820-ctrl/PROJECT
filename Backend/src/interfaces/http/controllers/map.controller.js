const mapboxService = require('../../../services/mapbox.service');

// Curated Agricultural Hubs & Farms across Cameroon for rich discovery
const DEMO_FARMS = [
    {
        id: 'farm-001',
        name: 'Foumbot High-Yield Tomato & Pepper Farm',
        farmerName: 'Jean-Paul Ndam',
        region: 'West Region (Foumbot)',
        coordinates: { longitude: 10.6311, latitude: 5.5083 },
        crops: ['Tomatoes', 'Bell Peppers', 'Carrots'],
        rating: 4.9,
        verified: true,
        phone: '+237 670 11 22 33',
        description: 'Fertile volcanic soil producing organic tomatoes and fresh bell peppers for local and wholesale markets.'
    },
    {
        id: 'farm-002',
        name: 'Njombe-Penja Plantain & Banana Plantation',
        farmerName: 'Alain Ekotto',
        region: 'Littoral (Njombe-Penja)',
        coordinates: { longitude: 9.6633, latitude: 4.5772 },
        crops: ['Plantains', 'Bananas', 'Penja White Pepper'],
        rating: 4.8,
        verified: true,
        phone: '+237 690 44 55 66',
        description: 'World-renowned Penja white pepper and premium organic sweet plantains harvested daily.'
    },
    {
        id: 'farm-003',
        name: 'Bamenda Highland Arabica Coffee & Cabbage',
        farmerName: 'Mary Lum Che',
        region: 'Northwest (Bamenda Santa)',
        coordinates: { longitude: 10.1591, latitude: 5.8617 },
        crops: ['Arabica Coffee', 'Cabbage', 'Potatoes'],
        rating: 4.95,
        verified: true,
        phone: '+237 677 88 99 00',
        description: 'Highland altitude specialty coffee and cool-climate organic cabbages and Irish potatoes.'
    },
    {
        id: 'farm-004',
        name: 'Obala Greenbelt Agro-Farm',
        farmerName: 'Ebenezer Mbarga',
        region: 'Centre (Obala - Yaounde North)',
        coordinates: { longitude: 11.5333, latitude: 4.1667 },
        crops: ['Cassava', 'Maize', 'Okra', 'Pineapples'],
        rating: 4.7,
        verified: true,
        phone: '+237 655 22 33 44',
        description: 'Primary organic cassava and sweet yellow maize farm supplying Yaounde central food markets.'
    },
    {
        id: 'farm-005',
        name: 'Bafoussam Poultry & Maize cooperative',
        farmerName: 'Dieudonne Kamga',
        region: 'West Region (Bafoussam)',
        coordinates: { longitude: 10.4179, latitude: 5.4777 },
        crops: ['Yellow Maize', 'Soya Beans', 'Poultry Feed'],
        rating: 4.85,
        verified: true,
        phone: '+237 671 23 45 67',
        description: 'Leading cooperative grain depot and organic feed supply hub for central Cameroon farmers.'
    }
];

class MapController {
    /**
     * Get public mapbox configuration
     */
    static getConfig(req, res) {
        res.status(200).json({
            status: 'success',
            data: {
                accessToken: mapboxService.accessToken,
                defaultCenter: {
                    latitude: 3.8480,
                    longitude: 11.5213,
                    name: 'Cameroon (Yaoundé)'
                },
                defaultZoom: 7,
                availableStyles: [
                    { id: 'outdoors-v12', name: 'Terrain & Agricultural Outdoors', preview: 'outdoors' },
                    { id: 'satellite-streets-v12', name: 'High-Res Satellite & Fields', preview: 'satellite' },
                    { id: 'streets-v12', name: 'Streets & Navigation', preview: 'streets' },
                    { id: 'light-v11', name: 'Clean Light', preview: 'light' }
                ]
            }
        });
    }

    /**
     * Search places / Geocoding
     */
    static async geocode(req, res) {
        try {
            const { q, country = 'cm', limit = 5, proximity, types } = req.query;

            if (!q) {
                return res.status(400).json({
                    status: 'error',
                    message: 'Query parameter "q" is required.'
                });
            }

            const results = await mapboxService.geocode(q, { country, limit: parseInt(limit, 10), proximity, types });

            res.status(200).json({
                status: 'success',
                data: results
            });
        } catch (error) {
            console.error('[MapController.geocode] Error:', error.message);
            res.status(500).json({
                status: 'error',
                message: error.message || 'Geocoding failed.'
            });
        }
    }

    /**
     * Reverse Geocode (lat, lng -> address)
     */
    static async reverseGeocode(req, res) {
        try {
            const { lat, lng } = req.query;

            if (!lat || !lng) {
                return res.status(400).json({
                    status: 'error',
                    message: 'Both "lat" and "lng" query parameters are required.'
                });
            }

            const results = await mapboxService.reverseGeocode(lng, lat);

            res.status(200).json({
                status: 'success',
                data: results
            });
        } catch (error) {
            console.error('[MapController.reverseGeocode] Error:', error.message);
            res.status(500).json({
                status: 'error',
                message: error.message || 'Reverse geocoding failed.'
            });
        }
    }

    /**
     * Calculate route, distance, travel duration and delivery fee
     */
    static async getDirections(req, res) {
        try {
            const originLng = req.query.originLng || req.body.originLng;
            const originLat = req.query.originLat || req.body.originLat;
            const destLng = req.query.destLng || req.body.destLng;
            const destLat = req.query.destLat || req.body.destLat;
            const profile = req.query.profile || req.body.profile || 'driving';

            if (!originLng || !originLat || !destLng || !destLat) {
                return res.status(400).json({
                    status: 'error',
                    message: 'originLng, originLat, destLng, and destLat are all required.'
                });
            }

            const directions = await mapboxService.getDirections({
                originLng,
                originLat,
                destLng,
                destLat,
                profile
            });

            // Add static route preview URL
            const staticRouteMapUrl = mapboxService.getRouteStaticMapUrl({
                originLng,
                originLat,
                destLng,
                destLat
            });

            res.status(200).json({
                status: 'success',
                data: {
                    ...directions,
                    staticRouteMapUrl
                }
            });
        } catch (error) {
            console.error('[MapController.getDirections] Error:', error.message);
            res.status(500).json({
                status: 'error',
                message: error.message || 'Route calculation failed.'
            });
        }
    }

    /**
     * Get Static map URL for a coordinate
     */
    static getStaticMap(req, res) {
        try {
            const { lat, lng, zoom = 12, width = 600, height = 400, style = 'outdoors-v12', markerLabel = 'farm', markerColor = '2E7D32', redirect = 'false' } = req.query;

            if (!lat || !lng) {
                return res.status(400).json({
                    status: 'error',
                    message: 'Both "lat" and "lng" query parameters are required.'
                });
            }

            const url = mapboxService.getStaticMapUrl({
                lng: parseFloat(lng),
                lat: parseFloat(lat),
                zoom: parseInt(zoom, 10),
                width: parseInt(width, 10),
                height: parseInt(height, 10),
                style,
                markerLabel,
                markerColor
            });

            if (redirect === 'true') {
                return res.redirect(url);
            }

            res.status(200).json({
                status: 'success',
                data: { url }
            });
        } catch (error) {
            console.error('[MapController.getStaticMap] Error:', error.message);
            res.status(500).json({
                status: 'error',
                message: error.message || 'Failed to generate static map URL.'
            });
        }
    }

    /**
     * Get registered farms & agricultural hubs
     */
    static getFarms(req, res) {
        const { crop, region } = req.query;
        let farms = [...DEMO_FARMS];

        if (crop) {
            farms = farms.filter(f => f.crops.some(c => c.toLowerCase().includes(crop.toLowerCase())));
        }

        if (region) {
            farms = farms.filter(f => f.region.toLowerCase().includes(region.toLowerCase()));
        }

        // Add static map preview URL to each farm
        const enriched = farms.map(f => ({
            ...f,
            mapPreviewUrl: mapboxService.getStaticMapUrl({
                lng: f.coordinates.longitude,
                lat: f.coordinates.latitude,
                zoom: 13,
                style: 'outdoors-v12',
                markerLabel: 'farm',
                markerColor: '2E7D32'
            })
        }));

        res.status(200).json({
            status: 'success',
            data: {
                total: enriched.length,
                farms: enriched
            }
        });
    }
}

module.exports = MapController;
