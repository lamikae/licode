var winston = require('winston');

var logger = function() {
  var rt = new winston.Logger({
      transports: [
        new winston.transports.Console({
          handleExceptions: true,
          timestamp: true,
          colorize: true,
          level: 'debug'
        })
      ],
      exitOnError: false
    });
    return rt;
}();

logger.info("Initialized logger");

exports.logger = logger;