export const Environment = {
	trade_feed_url: `http://${window.location.hostname}:18086`,
	account_service_url:  `http://${window.location.hostname}:18088`,
	trade_service_url:  `http://${window.location.hostname}:18092`,
	reference_data_url:  `http://${window.location.hostname}:18085`,
	people_service_url:  `http://${window.location.hostname}:18095`,
	position_service_url:  `http://${window.location.hostname}:18090`
	// Using the Nginx reverse proxy...
	// trade_feed_url: `https://${window.location.hostname}/trade-feed`,
	// account_service_url:  `https://${window.location.hostname}/account-service`,
	// trade_service_url:  `https://${window.location.hostname}/trade-service`,
	// reference_data_url:  `https://${window.location.hostname}/reference-data`,
	// people_service_url:  `https://${window.location.hostname}/people-service`,
	// position_service_url:  `https://${window.location.hostname}/position-service`
}
