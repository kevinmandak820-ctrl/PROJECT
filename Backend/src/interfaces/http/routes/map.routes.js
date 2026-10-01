const express = require('express');
const MapController = require('../controllers/map.controller');

const router = express.Router();

// Public configuration & default map bounds
router.get('/config', MapController.getConfig);

// Geocoding: search address/location
router.get('/geocode', MapController.geocode);

// Reverse geocoding: coordinates to address
router.get('/reverse', MapController.reverseGeocode);

// Route directions & delivery fee calculation (supports both GET and POST)
router.get('/directions', MapController.getDirections);
router.post('/directions', MapController.getDirections);

// Static map image URL generator
router.get('/static', MapController.getStaticMap);

// Registered agricultural hubs & demo farms
router.get('/farms', MapController.getFarms);

module.exports = router;
