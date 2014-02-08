var sys = require('util');
var rpcPublic = require('./rpcPublic');
var config = require('./../../../licode_config');
var logger = require('./../logger').logger;

var TIMEOUT = 2000;

var corrID = 0;
var corrs = {};	//{corrID: {fn: callback, to: timeout}}

var deferred = require('deferred');
var dnode = require('dnode');
var clientID;
var nuve;
var nuveSock = config.nuve.rpcSock || 3446;
var erizoControllerSock = config.erizoController.rpcSock || 3479;


exports.connect = function(callback) {
    // Open dnode RPC client to initiate intra-process communication with nuve.
    var nuveRpc = dnode.connect(nuveSock);
    var erizoControllerRpc;

    nuveRpc.on('remote', function (remote, d) {
        logger.info("Opened RPC channel to nuve @", nuveSock);
        nuve = remote;
        // Open dnode RPC server to publish rpcPublic interface for nuve.
        erizoControllerRpc = dnode(rpcPublic);
        erizoControllerRpc.listen(erizoControllerSock);
        logger.info("Listening to RPC @", erizoControllerSock);
        // connect ok
        callback();
    });

    nuveRpc.on('error', function (err) {
        logger.error("Nuve does not respond", err);
        // close my service
        if (erizoControllerRpc !== undefined) {
            erizoControllerRpc.end();
        }
        // try again
        setTimeout(function(){ exports.connect(callback); }, 5000);
    });
};

exports.bind = function(id, callback) {
    clientID = id;
    callback(id);
};

/*
 * Calls remotely the 'method' function defined in rpcPublic of 'to'.
 */
exports.callRpc = function(to, method, args, callback) {

    // use this deferred to call callback and cancel callbackError timeout.
    var d = deferred();

    corrID ++;
    corrs[corrID] = {};
    corrs[corrID].fn = callback;
    var timeout = setTimeout(callbackError, TIMEOUT, corrID);
    corrs[corrID].to = timeout;

    d.promise.then(function (msg) {
        if (method !== 'keepAlive') {
            logger.info(method, msg);
        }
        // Clear error callback as the call was successful;
        // clearing timeout from corrs[corrID].to causes mayhem
        clearTimeout(timeout);
        // Call RPC method
        corrs[corrID].fn(msg);
        delete corrs[corrID];
        // leave the socket open, it has to keepAlive
    }, function (err) {
        console.log(err);
        // the timeout will trigger
    });

    var send = {method: method, args: args, corrID: corrID, replyTo: clientID };

    // use existing RPC connection to nuve
    try {
        if (nuve !== undefined) {
            // logger.debug("Call nuve", method, args);
            fn = nuve[method];
            fn(args, d.resolve);
        }
        else {
            d.reject(new Error("Nuve RPC is not available!"));
        }
    }
    catch (err) {
        d.reject(err);
    }
};

var callbackError = function(corrID) {
    if (corrID !== undefined) {
        corrs[corrID].fn('timeout');
        delete corrs[corrID];
    }
};
