console.log('this is a test message');
var app = firebase.initializeApp(config);
const database = firebase.database()
const messaging = firebase.messaging();
var person = {
	uid: ''
};


firebase.auth().onAuthStateChanged(function(user) {
	if (user) {
		// User is signed in.
		person.uid = user.uid
		console.log(person.uid)
	} else {
		// No user is signed in.
	}
});

localStorage.clear();

console.log(person.uid);
messaging.usePublicVapidKey("BMaJZBrMHjjL4YnVSP34qfmWU_X37bfkkCnO35EJyY2Gdb7YDesYDdcKzQaxB2AUJrLS7tMA66GdF_97jAwodZA");

// IDs of divs that display Instance ID token UI or request permission UI.
const tokenDivId = 'token_div';
const permissionDivId = 'permission_div';

messaging.requestPermission().then(function() {
console.log('Notification permission granted.');
// Get Instance ID token. Initially this makes a network call, once retrieved
// subsequent calls to getToken will return from cache.

messaging.getToken().then(function(currentToken) {
	if (currentToken) {
		sendTokenToServer(currentToken);
		//updateUIForPushEnabled(currentToken);
	} else {
		// Show permission request.
		console.log('No Instance ID token available. Request permission to generate one.');
		// Show permission UI.
		updateUIForPushPermissionRequired();
		setTokenSentToServer(false);
	}
}).catch(function(err) {
	console.log('An error occurred while retrieving token. ', err);
	//showToken('Error retrieving Instance ID token. ', err);
	setTokenSentToServer(false);
	});
}).catch(function(err) {
console.log('Unable to get permission to notify.', err);
});

// Send the Instance ID token your application server, so that it can:
// - send messages back to this app
// - subscribe/unsubscribe the token from topics
function sendTokenToServer(currentToken) {
	if (!isTokenSentToServer()) {
		console.log('Sending token to server...');
		// TODO(developer): Send the current token to your server.
		sendTokenToServer(currentToken);
		setTokenSentToServer(true);
	} else {
		console.log('Token already sent to server so won\'t send it again ' +
		  'unless it changes');
	}
}




function sendTokenToServer(currentToken) {
	if (!isTokenSentToServer()) {
		console.log('Sending token to server...');
		console.log(currentToken);
		// TODO(developer): Send the current token to your server.
		var accountsRef = database.ref('/account_mapping');
		var notificationsRef = database.ref('/notification_tokens');

		firebase.auth().onAuthStateChanged(function(user) {
			if (user) {
				// User is signed in.
				accountsRef.child(currentToken).set(user.uid);
				notificationsRef.child(user.uid).child(currentToken).set(true)
			} else {
				// No user is signed in.
			}
		});


		setTokenSentToServer(true);
	} else {
		console.log(currentToken)
		console.log('Token already sent to server so won\'t send it again ' +
		  'unless it changes');
	}
}

function isTokenSentToServer() {
	return window.localStorage.getItem('sentToServer') === '1';
}

function setTokenSentToServer(sent) {
	window.localStorage.setItem('sentToServer', sent ? '1' : '0');
}
