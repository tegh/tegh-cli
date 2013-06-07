dgram = require('dgram')
dns = require('native-dns')
UDPSocket = require('native-dns/lib/utils').UDPSocket
DnsPacket = require('native-dns/lib/packet')
consts = require('native-dns/lib/consts')
util = require('util')
EventEmitter = require('events').EventEmitter

`var random_integer = function() {
  return Math.floor(Math.random() * 50000 + 1);
};`


module.exports = class DnsSdDiscoverer extends EventEmitter
  multicastAddresses:
    udp4: "224.0.0.251"
    udp6: "FF02::FB"
  mdnsServer: 
    port: 5353
    type: "udp"

  dnsSdOpts:
    name: "_services._dns-sd._udp.local"
    type: "PTR"

  constructor: (@filter) ->

  start: ->
    @start = Date.now()
    @_sockets = []

    for type, address of @multicastAddresses
      @_makeMdnsRequest type, address
    setTimeout(@close, 2000);

  _makeMdnsRequest: (type, address) ->
    server = 
      port: @mdnsServer.port
      type: @mdnsServer.type
      address: address
    question = dns.Question @dnsSdOpts
    dg = dgram.createSocket(type)
    socket = new UDPSocket dg, server

    req = dns.Request
      question: question
      server: server
      timeout: 2000

    packet = new DnsPacket(socket)
    packet.timeout = 2000
    packet.header.id = random_integer()
    packet.header.rd = 1
    packet.question.push(req.question)

    dg.on "message", @_onMessage

    packet.send()
    dg.ref()
    @_sockets.push dg

  close: =>
    for socket in @_sockets
      socket.unref()
      socket.close()
    # console.log "Closing the MDNS discovery udp connections"

  _onMessage: (buffer, rinfo) =>
    packet = DnsPacket.parse(buffer)
    services = []
    services.push a.data for a in packet.answer
    console.log "response"
    console.log services if rinfo.address == "192.168.111.23"
    for service in services
      continue unless service == @filter
      @emit "serviceUp",
        address: rinfo.address
        services: service
        name: @filter


new DnsSdDiscoverer()
