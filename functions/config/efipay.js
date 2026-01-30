const path = require('path');

module.exports = {
    sandbox: true,
    client_id: process.env.EFI_CLIENT_ID_HOMOLOG,
    client_secret: process.env.EFI_CLIENT_SECRET_HOMOLOG,
    certificate: path.resolve(__dirname, '../certs/homologacao.p12'),
    pem: false,
};
