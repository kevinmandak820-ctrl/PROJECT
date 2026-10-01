const https = require('https');
const config = require('../config');

/**
 * Mapbox Geolocation, Mapping & Routing Service
 * Handles Geocoding, Reverse Geocoding, Directions/Routing, and Static Maps via Mapbox API
 */
class MapboxService {
    constructor() {
        this.accessToken = config.mapbox?.accessToken || process.env.MAPBOX_ACCESS_TOKEN || '';
        this.baseUrl = 'https://api.mapbox.com';
    }

    /**
     * Internal helper to perform HTTPS GET requests
     */
    async _get(endpoint, params = {}) {
        const queryParams = new URLSearchParams({
            ...params,
            access_token: this.accessToken
        });

        const url = `${this.baseUrl}${endpoint}?${queryParams.toString()}`;

        return new Promise((resolve, reject) => {
            const req = https.get(url, { timeout: 15000 }, (res) => {
                let data = '';
                res.on('data', chunk => data += chunk);
                res.on('end', () => {
                    if (res.statusCode >= 200 && res.statusCode < 300) {
                        try {
                            const parsed = JSON.parse(data);
                            resolve(parsed);
                        } catch (err) {
                            reject(new Error(`Failed to parse Mapbox response: ${err.message}`));
                        }
                    } else {
                        reject(new Error(`Mapbox API error [${res.statusCode}]: ${data}`));
                    }
                });
            });

            req.on('timeout', () => {
                req.destroy();
                reject(new Error('Mapbox request timed out after 15 seconds'));
            });

            req.on('error', (err) => {
                reject(err);
            });
        });
    }

    /**
     * Forward Geocoding: search places, cities, farms, or addresses
     * 
     * @param {string} query Search text (e.g. "Yaounde", "Bafoussam Market", "Douala Bonanjo")
     * @param {object} options
     * @param {string} [options.country='cm'] Country code filter (default: Cameroon 'cm')
     * @param {number} [options.limit=5] Maximum results to return
     * @param {string} [options.proximity] Format "lng,lat" to bias results near user
     */
    async geocode(query, options = {}) {
        if (!query || typeof query !== 'string' || !query.trim()) {
            throw new Error('A search query string is required for geocoding.');
        }

        const params = {
            limit: options.limit || 5
        };

        if (options.country !== 'all') {
            params.country = options.country || 'cm';
        }

        if (options.proximity) {
            params.proximity = options.proximity;
        }

        if (options.types) {
            params.types = options.types;
        }

        const endpoint = `/geocoding/v5/mapbox.places/${encodeURIComponent(query.trim())}.json`;
        const result = await this._get(endpoint, params);

        return {
            query: query.trim(),
            totalResults: result.features?.length || 0,
            features: (result.features || []).map(f => ({
                id: f.id,
                placeName: f.place_name,
                name: f.text,
                coordinates: {
                    longitude: f.center[0],
                    latitude: f.center[1]
                },
                bbox: f.bbox || null,
                placeType: f.place_type || [],
                relevance: f.relevance,
                context: f.context || []
            }))
        };
    }

    /**
     * Reverse Geocoding: Convert GPS coordinates (longitude, latitude) into a human-readable address
     * 
     * @param {number} longitude 
     * @param {number} latitude 
     */
    async reverseGeocode(longitude, latitude) {
        const lng = parseFloat(longitude);
        const lat = parseFloat(latitude);

        if (isNaN(lng) || isNaN(lat)) {
            throw new Error('Valid numeric longitude and latitude coordinates are required.');
        }

        const endpoint = `/geocoding/v5/mapbox.places/${lng},${lat}.json`;
        const result = await this._get(endpoint, { limit: 1 });

        const primary = result.features?.[0];
        return {
            coordinates: { longitude: lng, latitude: lat },
            placeName: primary ? primary.place_name : 'Unknown Location',
            name: primary ? primary.text : 'Unknown',
            features: result.features || []
        };
    }

    /**
     * Directions & Routing: Calculate driving route, distance, duration, and delivery fee
     * 
     * @param {object} params
     * @param {number} params.originLng
     * @param {number} params.originLat
     * @param {number} params.destLng
     * @param {number} params.destLat
     * @param {string} [params.profile='driving'] driving, walking, cycling
     */
    async getDirections({ originLng, originLat, destLng, destLat, profile = 'driving' }) {
        const oLng = parseFloat(originLng);
        const oLat = parseFloat(originLat);
        const dLng = parseFloat(destLng);
        const dLat = parseFloat(destLat);

        if ([oLng, oLat, dLng, dLat].some(isNaN)) {
            throw new Error('Valid origin (lng, lat) and destination (lng, lat) are required.');
        }

        const coordinates = `${oLng},${oLat};${dLng},${dLat}`;
        const endpoint = `/directions/v5/mapbox/${profile}/${coordinates}`;

        const result = await this._get(endpoint, {
            geometries: 'geojson',
            overview: 'full',
            steps: 'true'
        });

        if (!result.routes || result.routes.length === 0) {
            throw new Error('No route found between the specified coordinates.');
        }

        const route = result.routes[0];
        const distanceKm = Math.round((route.distance / 1000) * 10) / 10;
        const durationMinutes = Math.round(route.duration / 60);
        const deliveryFee = this.calculateDeliveryFee(distanceKm);

        return {
            profile,
            distanceMeters: route.distance,
            distanceKm,
            durationSeconds: route.duration,
            durationMinutes,
            deliveryFeeXAF: deliveryFee,
            routeGeometry: route.geometry,
            waypoints: result.waypoints || [],
            steps: (route.legs?.[0]?.steps || []).map(s => ({
                instruction: s.maneuver?.instruction || '',
                distanceMeters: s.distance,
                durationSeconds: s.duration,
                name: s.name || ''
            }))
        };
    }

    /**
     * Calculate delivery fee in XAF based on distance (km)
     * Base: 500 XAF
     * Per km: 150 XAF
     * 
     * @param {number} distanceKm 
     * @returns {number} Fee in XAF rounded to 50
     */
    calculateDeliveryFee(distanceKm) {
        if (!distanceKm || distanceKm <= 0) return 500;
        const base = 500;
        const ratePerKm = 150;
        const calculated = base + (distanceKm * ratePerKm);
        return Math.round(calculated / 50) * 50; // Round to nearest 50 XAF
    }

    /**
     * Generate static snapshot map image URL with marker
     * 
     * @param {object} params
     * @param {number} params.lng Longitude
     * @param {number} params.lat Latitude
     * @param {number} [params.zoom=12]
     * @param {number} [params.width=600]
     * @param {number} [params.height=400]
     * @param {string} [params.style='outdoors-v12'] outdoors-v12, streets-v12, satellite-streets-v12, dark-v11
     * @param {string} [params.markerLabel='farm'] pin marker icon (e.g. 'farm', 'marker', 'circle')
     * @param {string} [params.markerColor='2E7D32'] hex color without '#'
     */
    getStaticMapUrl({ lng, lat, zoom = 12, width = 600, height = 400, style = 'outdoors-v12', markerLabel = 'farm', markerColor = '2E7D32' }) {
        const pin = `pin-s-${markerLabel}+${markerColor}(${lng},${lat})`;
        return `${this.baseUrl}/styles/v1/mapbox/${style}/static/${pin}/${lng},${lat},${zoom},0/${width}x${height}@2x?access_token=${this.accessToken}`;
    }

    /**
     * Generate static route map image URL connecting origin and destination
     */
    getRouteStaticMapUrl({ originLng, originLat, destLng, destLat, width = 600, height = 400, style = 'streets-v12' }) {
        const originPin = `pin-s-farm+2E7D32(${originLng},${originLat})`;
        const destPin = `pin-s-car+E65100(${destLng},${destLat})`;
        // Use 'auto' to auto-fit both pins into the viewport
        return `${this.baseUrl}/styles/v1/mapbox/${style}/static/${originPin},${destPin}/auto/${width}x${height}@2x?padding=40&access_token=${this.accessToken}`;
    }
}

module.exports = new MapboxService();
