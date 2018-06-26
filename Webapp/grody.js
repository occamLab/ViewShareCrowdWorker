const messaging = firebase.messaging();
messaging.usePublicVapidKey("BMaJZBrMHjjL4YnVSP34qfmWU_X37bfkkCnO35EJyY2Gdb7YDesYDdcKzQaxB2AUJrLS7tMA66GdF_97jAwodZA")
messaging.requestPermission().then(function() {
  console.log('Notification permission granted.');
  // TODO(developer): Retrieve an Instance ID token for use with FCM.
  // ...
  // Get Instance ID token. Initially this makes a network call, once retrieved
	// subsequent calls to getToken will return from cache.
	messaging.getToken().then(function(currentToken) {
	  if (currentToken) {
		sendTokenToServer(currentToken);
		updateUIForPushEnabled(currentToken);
	  } else {
		// Show permission request.
		console.log('No Instance ID token available. Request permission to generate one.');
		// Show permission UI.
		updateUIForPushPermissionRequired();
		setTokenSentToServer(false);
	  }
	}).catch(function(err) {
	  console.log('An error occurred while retrieving token. ', err);
	  showToken('Error retrieving Instance ID token. ', err);
	  setTokenSentToServer(false);
	});
}).catch(function(err) {
  console.log('Unable to get permission to notify.', err);
});
