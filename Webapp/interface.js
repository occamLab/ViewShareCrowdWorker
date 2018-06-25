// Initialize the default app
var app = firebase.initializeApp(defaultAppConfig);

console.log(defaultApp.name);  // "[DEFAULT]"

// You can retrieve services via the defaultApp variable...
var storage = defaultApp.storage();
var database = defaultApp.database();

class job {
	
}
