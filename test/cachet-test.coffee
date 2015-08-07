chai   = require 'chai'
helper = require './test-helper'
assert = chai.assert
nock   = require 'nock'

process.env.HUBOT_CACHET_API_URL = 'http://cachet.example.org'
api = nock(process.env.HUBOT_CACHET_API_URL).filteringPath(/\/\//, '/')

describe 'cachet', ->
  beforeEach (done) ->
    @robot = helper.robot()
    @user  = helper.testUser @robot
    @robot.adapter.on 'connected', ->
      @robot.loadFile  helper.SRC_PATH, 'cachet.coffee'
      @robot.parseHelp "#{helper.SRC_PATH}/cachet.coffee"
      done()
    @robot.run()

  afterEach ->
    @robot.shutdown()

  it 'should be included in /help', ->
    assert.include @robot.commands[0], 'cachet'

  describe 'component commands', ->
    it 'should report when there are no components registered', (done) ->
      helper.converse @robot, @user, '/cachet component list', (envelope, response) ->
        assert.include response, 'No component found'
        done()

    it 'should register components', (done) ->
      helper.converse @robot, @user, '/cachet component set foo 1', (envelope, response) ->
        assert.include response, 'The component \'foo\' (id = 1) has been set'

      helper.converse @robot, @user, '/cachet component list', (envelope, response) ->
        assert.include response, 'foo with id = 1'
        done()

    it 'should flush all components', (done) ->
      helper.converse @robot, @user, '/cachet component flushall', (envelope, response) ->
        assert.include response, 'Roger!'

      helper.converse @robot, @user, '/cachet component list', (envelope, response) ->
        assert.include response, 'No component found'
        done()

  describe 'incident commands', ->
    it 'should allow to create "investigating" incidents', (done) ->
      json = {
        name:"foo",
        message:"msg",
        status:1,
        component_id:0,
        notify:true
      }

      api.post('/incidents', json).reply(201, { data: { id: 123 } })

      helper.converse @robot, @user, '/incident investigating on foo: msg', (envelope, response) ->
        assert.include response, 'Incident `#123` declared'
        done()

    it 'should allow to create "identified" incidents', (done) ->
      json = {
        name:"foo",
        message:"msg",
        status:2,
        component_id:0,
        notify:true
      }

      api.post('/incidents', json).reply(201, { data: { id: 124 } })

      helper.converse @robot, @user, '/incident identified on foo: msg', (envelope, response) ->
        assert.include response, 'Incident `#124` declared'
        done()

    it 'should allow to create "watching" incidents', (done) ->
      json = {
        name:"foo",
        message:"msg",
        status:3,
        component_id:0,
        notify:true
      }

      api.post('/incidents', json).reply(201, { data: { id: 125 } })

      helper.converse @robot, @user, '/incident watching on foo: msg', (envelope, response) ->
        assert.include response, 'Incident `#125` declared'
        done()

    it 'should allow to create "fixed" incidents', (done) ->
      json = {
        name:"foo",
        message:"msg",
        status:4,
        component_id:0,
        notify:true
      }

      api.post('/incidents', json).reply(201, { data: { id: 126 } })

      helper.converse @robot, @user, '/incident fixed on foo: msg', (envelope, response) ->
        assert.include response, 'Incident `#126` declared'
        done()
