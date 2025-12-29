const hotelController = require('./controllers/hotelController');
const agendamentoController = require('./controllers/agendamentoController');

// Exporta as funções para o Firebase Cloud Functions

// Grupo Hotel
exports.reservarHotel = hotelController.reservar;

// Grupo Agendamento & Pagamento
exports.buscarHorarios = agendamentoController.buscarHorarios;
exports.criarAgendamento = agendamentoController.criar;
exports.webhookPix = agendamentoController.webhookPix;