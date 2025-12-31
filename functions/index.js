// index.js

// 1. IMPORTAÇÕES OBRIGATÓRIAS
const { setGlobalOptions } = require("firebase-functions/v2");
const { onRequest } = require("firebase-functions/v2/https");
const logger = require("firebase-functions/logger");

// 2. CONFIGURAÇÃO GLOBAL (Sul do Brasil)
setGlobalOptions({ region: "southamerica-east1" });

// 3. IMPORTAÇÕES DOS CONTROLLERS
const agendamentoController = require('./controllers/agendamentoController');
const hotelController = require('./controllers/hotelController');

// 4. EXPORTAÇÕES (O que o Firebase vai enxergar)

// --- Módulo de Agendamento ---
exports.buscarHorarios = agendamentoController.buscarHorarios;
exports.criarAgendamento = agendamentoController.criarAgendamento;
exports.comprarAssinatura = agendamentoController.comprarAssinatura; // <--- Importante! Faltava essa.
exports.webhookPix = agendamentoController.webhookPix;

// --- Módulo de Hotelzinho ---
exports.reservarHotel = hotelController.reservarHotel;
exports.obterDiasLotados = hotelController.obterDiasLotados;