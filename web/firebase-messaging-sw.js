importScripts("https://www.gstatic.com/firebasejs/9.22.0/firebase-app-compat.js");
importScripts("https://www.gstatic.com/firebasejs/9.22.0/firebase-messaging-compat.js");

// Suas configurações do Firebase (Pegue no Console > Configurações do Projeto > Geral > Apps da Web)
firebase.initializeApp({
    apiKey: "AIzaSyAU7mFrMbCx3KT3aJmCrMAvKmYm6JgL_G8",
    authDomain: "agenpets.firebaseapp.com",
    projectId: "agenpets",
    storageBucket: "agenpets.firebasestorage.app",
    messagingSenderId: "936955635480",
    appId: "1:936955635480:web:9e72de52b52eabf786e06d",
    measurementId: "G-07D8MQ3W98"
});

const messaging = firebase.messaging();

// Opcional: lidar com mensagens em segundo plano
messaging.onBackgroundMessage(function (payload) {
    console.log('[firebase-messaging-sw.js] Recebeu mensagem em background ', payload);

    const notificationTitle = payload.notification.title;
    const notificationOptions = {
        body: payload.notification.body,
        //icon: '/icons/Icon-192.png' // Verifique se o ícone existe
    };

    self.registration.showNotification(notificationTitle, notificationOptions);
});