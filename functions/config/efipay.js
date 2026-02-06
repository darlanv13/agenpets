const path = require('path');

module.exports = {
    sandbox: true,
    certificate: path.resolve(__dirname, '../certs/producao-644069-agenpets.p12'),
    pem: false,
};
