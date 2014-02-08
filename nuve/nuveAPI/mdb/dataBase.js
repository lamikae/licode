/*global require, exports*/
var config = require('./../../../licode_config');

// Tokens will be given a new uuid
var uuid = require("node-uuid");

/*
 * Data base collections and its fields are:
 *
 * room {name: '', [p2p: bool], [data: {}], _id: ObjectId}
 *
 * service {name: '', key: '', rooms: Array[room], testRoom: room, testToken: token, _id: ObjectId}
 *
 * token {host: '', userName: '', room: '', role: '', service: '', creationDate: Date(), [use: int], [p2p: bool], _id: ObjectId}
 *
 */
var mongo_collections = ["rooms", "tokens", "services"];

// Superservice ID
exports.superService = config.nuve.superserviceID || require("os").hostname();

// Superservice key
exports.nuveKey = config.nuve.superserviceKey;

exports.testErizoController = config.nuve.testErizoController;

// If superserviceDB is set, an in-memory database is used instea of mongodb.
// We shall we call it kolibriDB. This database has no persistance over process lifetime.
if (config.nuve.superserviceDB !== undefined) {
  console.log("INFO: using kolibriDB");
  var kolibriDB = require(config.nuve.superserviceDB);
  exports.kolibriDB = kolibriDB;

  // A single super service is created at startup.
  var superService = {
    name: "licode-minima",
    _id: exports.superService,
    key: exports.nuveKey,
    rooms: [],
    testRoom: {},
  };

  // Set Room defaults.
  // There is something wrong with p2p rooms.
  kolibriDB.rooms.forEach(function(room) {
    if (room.p2p === undefined) {room.p2p = false;}
    // if (room.data === undefined) {room.data = {};}
    superService.rooms.push(room);
  });

  // Store tokens in memory
  kolibriDB.tokens = [];

  // Store superService to memory
  kolibriDB.superService = superService;

  // Don't use mongodb
  mongo_collections = [];
}
// Load mongojs if any mongo_collections are defined
// To work, the corresponding nuveAPI/mdb/*Registry needs to be
// changed to use the export "mongodb" instead of "db" from here.
if (mongo_collections.length > 0) {
  var databaseUrl = config.nuve.dataBaseURL;
  exports.mongodb = require("mongojs").connect(databaseUrl, mongo_collections);
}

// In-memory database mimicking mongodb API.
// Callbacks expect error as first param, value as the second param.
// TODO: wrap callbacks in (callback !== undefined) {}
exports.db = {
  rooms: {
    find: function(options, callback) {
      // console.log("dataBase.js: find rooms", options);
      var rooms = kolibriDB.rooms.filter(filterStaticDB, options);
      callback(undefined, rooms);
    },
    findOne: function(options, callback) {
      // console.log("dataBase.js: find room", options);
      var room = kolibriDB.rooms.filter(filterStaticDB, options)[0];
      callback(undefined, room);
    },
    // the following api methods are not implemented
    save: function(room, callback) {
      callback("Unimplemented");
    },
    remove: function(room, callback) {
      callback("Unimplemented");
    }
  },

  tokens: {
    find: function(options, callback) {
      // console.log("dataBase.js: find tokens", options);
      var tokens = kolibriDB.tokens.filter(filterStaticDB, options);
      callback(undefined, tokens);
    },
    findOne: function(options, callback) {
      // console.log("dataBase.js: findOne token", options);
      var token = kolibriDB.tokens.filter(filterStaticDB, options)[0];
      callback(undefined, token);
    },
    save: function(token, callback) {
      if (token._id === undefined) {
        // generate random uuid
        token._id = uuid.v4();
      }
      // console.log("dataBase.js: save token", token);
      kolibriDB.tokens.push(token);
      callback(undefined, token);
    },
    remove: function(options, callback) {
      // not being perserved on file, all tokens are cleared at exit
      var tokens = kolibriDB.tokens.filter(filterStaticDB, options);
      var i;
      for (i in tokens) {
        var ki = kolibriDB.tokens.indexOf(tokens[i]);
        // console.log("dataBase.js: remove token", kolibriDB.tokens[ki]._id);
        kolibriDB.tokens.splice(ki, 1);
      }
      callback(undefined, true);
    }
  },

  services: {
    find: function(options, callback) {
      // console.log("dataBase.js: find services", options);
      services = [exports.kolibriDB.superService].filter(filterStaticDB, options);
      callback(undefined, services);
    },
    findOne: function(options, callback) {
      // console.log("dataBase.js: findOne service", options);
      service = [exports.kolibriDB.superService].filter(filterStaticDB, options)[0];
      callback(undefined, service);
    },
    // Super service is static, but the room list is not
    save: function(service, callback) {
      if (service._id != superService._id) {
        callback("Unimplemented");
      } else {
        superService = service;
        callback(undefined, true);
      }
    },
    remove: function(service, callback) {
      callback("Unimplemented");
    }
  }
};

// NOTE: This function is passed as a parameter in tokens.filter(filterStaticDB, options)
//       And "this" will become "options" within this context.
filterStaticDB = function(record) {
  recordMatch = Object.keys(this);
  return recordMatch.filter(function(key) {
    return record[key] == this[key];
  }, this).length == recordMatch.length; // all options have to match
};
