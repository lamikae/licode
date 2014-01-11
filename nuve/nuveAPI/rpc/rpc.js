/*global exports, require, console, Buffer, setTimeout, clearTimeout*/
var sys = require('util');
var rpcPublic = require('./rpcPublic');
var config = require('./../../../licode_config');

var TIMEOUT = 3000;

var corrID = 0;
var corrs = {};   //{corrID: {fn: callback, to: timeout}}

var deferred = require('deferred');
var dnode = require('dnode');
var nuveSock = config.nuve.rpcSock || 3446;
var erizoControllerSock = config.erizoController.rpcSock || 3479;


// This connect is called at Nuve startup, when erizoControllers are not yet online.
// Opens dnode RPC server to publish rpcPublic interface for erizoControllers.
exports.connect = function () {
    /* When using unix sockets,
       to use an existing socket file,
       the method you’re looking for is net.createConnection(path):

http://www.ggkf.com/node-js/connecting-to-an-already-established-unix-socket-with-node-js

    */
    var nuveRpc = dnode(rpcPublic);
    nuveRpc.listen(nuveSock);
    nuveRpc.on('error', function (err) {
        console.log("ERROR: could not open RPC server", err);
        process.exit(1);
    });
    console.log("INFO: Listening to RPC @", nuveSock);
};


var callbackError = function (corrID) {
    if (corrID !== undefined) {
        corrs[corrID].fn('timeout');
        delete corrs[corrID];
    }
};

/*
 *  Calls erizoController remotely.
 *  Has not been tested with multiple controllers.
 */
exports.callRpc = function (to, method, args, callback) {

    // use this deferred to call callback and cancel callbackError timeout.
    var d = deferred();

    corrID ++;
    corrs[corrID] = {};
    corrs[corrID].fn = callback;
    var timeout = setTimeout(callbackError, TIMEOUT, corrID);
    corrs[corrID].to = timeout;

    // Open a temporary RPC connection to erizoController
    var erizoControllerRpc;

    d.promise.then(function (msg) {
        // Clear error callback as the call was successful;
        // clearing timeout from corrs[corrID].to causes mayhem
        clearTimeout(timeout);
        // Call RPC method
        corrs[corrID].fn(msg);
        delete corrs[corrID];
        // close RPC
        erizoControllerRpc.end();
    }, function (err) {
        console.log(err);
        // the timeout will trigger
    });

    // Reply "to" is a little shady here..
    // TODO: test with multiple erizoControllers
    var send = {method: method, args: args, corrID: corrID, replyTo: to};

    // open the RPC connection to erizoController here
    try {
        erizoControllerRpc = dnode.connect(erizoControllerSock);
        erizoControllerRpc.on('remote', function (remote) {
            // console.log("DEBUG: Opened RPC channel to erizoController @", erizoControllerSock);
            // Call RPC method
            fn = remote[method];
            fn(args, d.resolve);
        });
    }
    catch (err) {
        d.reject(err);
    }
};

