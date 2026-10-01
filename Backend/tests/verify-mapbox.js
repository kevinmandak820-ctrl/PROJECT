require('dotenv').config();
const mapboxService = require('../src/services/mapbox.service');

async function verifyMapbox() {
    console.log('====================================================');
    console.log('--- Testing Mapbox Integration, Geocoding & Routing ---');
    console.log('====================================================');

    // 1. Verify Configuration & Token
    console.log('\n[1] Checking Mapbox Token:');
    const hasToken = Boolean(mapboxService.accessToken);
    const tokenPreview = mapboxService.accessToken ? mapboxService.accessToken.substring(0, 15) + '...' : 'NONE';
    console.log(`    Token Present: ${hasToken} (${tokenPreview})`);

    if (!hasToken) {
        throw new Error('MAPBOX_ACCESS_TOKEN is not defined in environment!');
    }

    // 2. Test Forward Geocoding (Yaoundé & Douala)
    console.log('\n[2] Testing Forward Geocoding (Mapbox Places API):');
    try {
        const yaoundeResults = await mapboxService.geocode('Yaounde', { country: 'cm' });
        console.log(`    ✅ Geocode "Yaounde": Found ${yaoundeResults.totalResults} features`);
        if (yaoundeResults.features.length > 0) {
            const first = yaoundeResults.features[0];
            console.log(`       Top match: "${first.placeName}" at [${first.coordinates.longitude}, ${first.coordinates.latitude}]`);
        } else {
            throw new Error('Geocoding returned 0 features for Yaounde');
        }

        const bafoussamResults = await mapboxService.geocode('Bafoussam Market', { country: 'cm' });
        console.log(`    ✅ Geocode "Bafoussam Market": Found ${bafoussamResults.totalResults} features`);
        if (bafoussamResults.features.length > 0) {
            console.log(`       Top match: "${bafoussamResults.features[0].placeName}"`);
        }
    } catch (err) {
        console.error('    ❌ Geocoding failed:', err.message);
        throw err;
    }

    // 3. Test Reverse Geocoding
    console.log('\n[3] Testing Reverse Geocoding (Coordinates -> Address):');
    try {
        const reverse = await mapboxService.reverseGeocode(11.5213, 3.8480);
        console.log(`    ✅ Reverse Geocode [11.5213, 3.8480]:`);
        console.log(`       Address: "${reverse.placeName}"`);
    } catch (err) {
        console.error('    ❌ Reverse geocoding failed:', err.message);
        throw err;
    }

    // 4. Test Directions & Routing (Douala -> Yaoundé)
    console.log('\n[4] Testing Directions & Driving Route (Douala to Yaoundé):');
    try {
        const doualaCoords = { lng: 9.7042, lat: 4.0511 };
        const yaoundeCoords = { lng: 11.5213, lat: 3.8480 };

        const directions = await mapboxService.getDirections({
            originLng: doualaCoords.lng,
            originLat: doualaCoords.lat,
            destLng: yaoundeCoords.lng,
            destLat: yaoundeCoords.lat,
            profile: 'driving'
        });

        console.log('    ✅ Driving Directions Retrieved:');
        console.log(`       Distance:     ${directions.distanceKm} km (${directions.distanceMeters} meters)`);
        console.log(`       Est Duration: ${directions.durationMinutes} mins (${(directions.durationMinutes / 60).toFixed(1)} hrs)`);
        console.log(`       Delivery Fee: ${directions.deliveryFeeXAF} XAF`);
        console.log(`       Steps count:  ${directions.steps.length}`);
        if (directions.steps.length > 0) {
            console.log(`       First step:   "${directions.steps[0].instruction}"`);
        }
    } catch (err) {
        console.error('    ❌ Directions failed:', err.message);
        throw err;
    }

    // 5. Test Delivery Fee Calculation
    console.log('\n[5] Testing Delivery Fee Calculation Matrix:');
    const feeTestCases = [
        { km: 0, expected: 500 },
        { km: 5, expected: 1250 },   // 500 + 5*150 = 1250
        { km: 10, expected: 2000 },  // 500 + 10*150 = 2000
        { km: 25.4, expected: 4300 } // 500 + 25.4*150 = 4310 -> round to nearest 50 = 4300
    ];

    for (const tc of feeTestCases) {
        const fee = mapboxService.calculateDeliveryFee(tc.km);
        const pass = fee === tc.expected;
        console.log(`    ${pass ? '✅' : '❌'} ${tc.km} km -> ${fee} XAF (Expected: ${tc.expected} XAF)`);
        if (!pass) throw new Error(`Fee calculation mismatch for ${tc.km} km: got ${fee}, expected ${tc.expected}`);
    }

    // 6. Test Static Map URLs
    console.log('\n[6] Testing Static Map URL Generation:');
    const staticMap = mapboxService.getStaticMapUrl({
        lng: 11.5213,
        lat: 3.8480,
        zoom: 12,
        style: 'outdoors-v12'
    });
    console.log(`    ✅ Static Map URL Generated: ${staticMap.substring(0, 80)}...`);

    const routeStatic = mapboxService.getRouteStaticMapUrl({
        originLng: 9.7042,
        originLat: 4.0511,
        destLng: 11.5213,
        destLat: 3.8480
    });
    console.log(`    ✅ Route Static Map URL Generated: ${routeStatic.substring(0, 80)}...`);

    console.log('\n🎉 ALL MAPBOX TESTS PASSED SUCCESSFULLY! 🎉\n');
}

verifyMapbox()
    .then(() => process.exit(0))
    .catch((err) => {
        console.error('FATAL Mapbox Verification Error:', err);
        process.exit(1);
    });
