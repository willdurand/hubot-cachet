chai = require 'chai'
sinon = require 'sinon'
chai.use require 'sinon-chai'

expect = chai.expect

describe 'cachet', ->
  beforeEach ->
    @robot =
      respond: sinon.spy()
      hear: sinon.spy()
      brain:
        on: (_, cb) ->
          cb()
        data: {}

    require('../src/cachet')(@robot)

  shouldRespondTo = (command) ->
    it "should respond to '#{command}'", ->
      expect(@robot.respond).to.have.been.calledWith(command)

  shouldRespondTo /cachet status/i
  shouldRespondTo /cachet component list/i
  shouldRespondTo /cachet component flushall/i
  shouldRespondTo /cachet component set ([a-zA-Z0-9]+) ([0-9]+)/i
