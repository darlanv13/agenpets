const admin = require("firebase-admin");
const {getFirestore} = require("firebase-admin/firestore");

if (!admin.apps.length) {
  admin.initializeApp();
}

// AQUI ESTÁ O SEGREDO: Conectar explicitamente no banco 'agenpets'
const db = getFirestore("agenpets");

module.exports = {db, admin};
