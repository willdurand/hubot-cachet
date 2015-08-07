chai   = require 'chai'
helper = require './test-helper'
assert = chai.assert
nock   = require 'nock'

process.env.HUBOT_CACHET_API_URL = 'http://cachet.example.org'
api = nock(process.env.HUBOT_CACHET_API_URL).filteringPath(/\/\//, '/')

describe 'hubot cachet', ->
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

  describe 'cachet component list', ->
    it 'should say when there are no components registered', (done) ->
      helper.converse @robot, @user, '/cachet component list', (envelope, response) ->
        assert.include response, 'No component found'
        done()

  describe 'cachet component set <component name> <id>', ->
    it 'should register components', (done) ->
      helper.converse @robot, @user, '/cachet component set foo 1', (envelope, response) ->
        assert.include response, 'The component \'foo\' (id = 1) has been set'

      helper.converse @robot, @user, '/cachet component list', (envelope, response) ->
        assert.include response, 'foo with id = 1'
        done()

  describe 'cachet component flushall', ->
    it 'should flush all components', (done) ->
      helper.converse @robot, @user, '/cachet component flushall', (envelope, response) ->
        assert.include response, 'Roger!'

      helper.converse @robot, @user, '/cachet component list', (envelope, response) ->
        assert.include response, 'No component found'
        done()

  describe 'cachet component status', ->
    it 'should show component statuses', (done) ->
      components = [
        { name: 'bar', status_name: 'Operational', updated_at: 'date' },
        { name: 'baz', status_name: 'Major outage', updated_at: 'date' },
      ]

      api.get('/components').reply(200, { data: components })

      helper.converse @robot, @user, '/cachet component status', (envelope, response) ->
        assert.equal response, [
          'bar: Operational (last updated at: date)',
          'baz: Major outage (last updated at: date)'
        ].join '\n'
        done()

    it 'should say when there are no component statuses available', (done) ->
      api.get('/components').reply(200, { data: [] })

      helper.converse @robot, @user, '/cachet component status', (envelope, response) ->
        assert.equal response, 'No component found'
        done()

    it 'should deal with API errors', (done) ->
      api.get('/components').reply(500)

      helper.converse @robot, @user, '/cachet component status', (envelope, response) ->
        assert.equal response, 'The request to the API has failed (status code = 500)'
        done()

  describe 'incident investigating on <component name>: <incident message>', ->
    it 'should allow to declare "investigating" incidents', (done) ->
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

  describe 'incident identified on <component name>: <incident message>', ->
    it 'should allow to declare "identified" incidents', (done) ->
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

  describe 'incident watching on <component name>: <incident message>', ->
    it 'should allow to declare "watching" incidents', (done) ->
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

  describe 'incident fixed on <component name>: <incident message>', ->
    it 'should allow to declare "fixed" incidents', (done) ->
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

  describe 'incident commands', ->
    it 'should allow to declare incidents on known components', (done) ->
      helper.converse @robot, @user, '/cachet component set foo 3', (envelope, response) ->
        assert.include response, 'The component \'foo\' (id = 3) has been set'

      json = {
        name:"foo is back!",
        message:"msg",
        status:4,
        component_id:3,
        notify:true
      }

      api.post('/incidents', json).reply(201, { data: { id: 127 } })

      helper.converse @robot, @user, '/incident fixed on foo: msg', (envelope, response) ->
        assert.include response, 'Incident `#127` declared'
        done()

    it 'should deal with API errors', (done) ->
      helper.converse @robot, @user, '/cachet component set foo 3', (envelope, response) ->
        assert.include response, 'The component \'foo\' (id = 3) has been set'

      json = {
        name:"foo is back!",
        message:"msg",
        status:4,
        component_id:3,
        notify:true
      }

      api.post('/incidents', json).reply(400)

      helper.converse @robot, @user, '/incident fixed on foo: msg', (envelope, response) ->
        assert.include response, 'The request to the API has failed (status code = 400)'
        done()

  describe 'cachet status <red|orange|blue|green> <component name>', ->
    it 'should allow to update a component status', (done) ->
      helper.converse @robot, @user, '/cachet component set foo 3', (envelope, response) ->
        assert.include response, 'The component \'foo\' (id = 3) has been set'

      api.put('/components/3', { status: 4 }).reply(200, { data: {
        name: 'foo',
        status_name: 'new status'
      }})

      helper.converse @robot, @user, '/cachet status red foo', (envelope, response) ->
        assert.equal response, 'foo status changed to: *new status*'
        done()

    it 'should deal with API errors', (done) ->
      helper.converse @robot, @user, '/cachet component set foo 3', (envelope, response) ->
        assert.include response, 'The component \'foo\' (id = 3) has been set'

      api.put('/components/3', { status: 2 }).reply(409)

      helper.converse @robot, @user, '/cachet status blue foo', (envelope, response) ->
        assert.equal response, 'The request to the API has failed (status code = 409)'
        done()
