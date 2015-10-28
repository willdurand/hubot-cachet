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

  it 'should be included in /help', (done) ->
    assert.include @robot.commands[0], 'cachet'
    done()

  describe 'cachet component list', ->
    it 'should say when there are no components registered', (done) ->
      helper.converse @robot, @user, '/cachet component list', (envelope, response) ->
        assert.include response, 'No component found'
        done()

  describe 'cachet component set <component name> <id>', ->
    it 'should register components', (done) ->
      helper.converse @robot, @user, '/cachet component set foo 1', (envelope, response) ->
        assert.include response, 'The component \'foo\' (id = 1) has been set'
        done()

    it 'should list the component', (done) ->
      helper.converse @robot, @user, '/cachet component list', (envelope, response) ->
        assert.include response, 'foo with id = 1'
        done()

  describe 'cachet component flushall', ->
    it 'should flush all components', (done) ->
      helper.converse @robot, @user, '/cachet component flushall', (envelope, response) ->
        assert.include response, 'Roger!'
        done()

    it 'should return an empty list with a nice message', (done) ->
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
          'bar: Operational (last updated: date)',
          'baz: Major outage (last updated: date)'
        ].join '\n'
        done()

    it 'should pretty format dates', (done) ->
      components = [
        { name: 'bar', status_name: 'Operational', updated_at: '2015-08-06 15:16:48' },
      ]

      api.get('/components').reply(200, { data: components })

      helper.converse @robot, @user, '/cachet component status', (envelope, response) ->
        assert.match response, /^bar: Operational \(last updated: (.+)\)$/
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
    it 'should have one component set before', (done) ->
      helper.converse @robot, @user, '/cachet component set foo 3', (envelope, response) ->
        assert.include response, 'The component \'foo\' (id = 3) has been set'
        done()

    it 'should allow to declare incidents on known components', (done) ->
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

  describe 'incident commands (errors)', ->
    it 'should jave one component set before', (done) ->
      helper.converse @robot, @user, '/cachet component set foo 3', (envelope, response) ->
        assert.include response, 'The component \'foo\' (id = 3) has been set'
        done()

    it 'should deal with API errors', (done) ->
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
    it 'should have one component set before', (done) ->
      helper.converse @robot, @user, '/cachet component set foo 3', (envelope, response) ->
        assert.include response, 'The component \'foo\' (id = 3) has been set'
        done()

    it 'should allow to update a component status', (done) ->
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
        done()

    it 'should deal with API errors', (done) ->
      api.put('/components/3', { status: 2 }).reply(409)

      helper.converse @robot, @user, '/cachet status blue foo', (envelope, response) ->
        assert.equal response, 'The request to the API has failed (status code = 409)'
        done()

  describe 'cachet maintenance at <scheduled_at> <name>: <message>', ->
    it 'should create a new maintenance', (done) ->
      json = {
        name:"Foo is upgraded",
        message:"This is a maintenance message",
        status:0,
        component_id:0,
        notify:true,
        scheduled_at: '2015-08-15 10:00:00'
      }

      api.post('/incidents', json).reply(201, { data: { id: 456 } })

      helper.converse @robot, @user, '/cachet maintenance at 2015-08-15 10:00:00 Foo is upgraded: This is a maintenance message', (envelope, response) ->
        assert.include response, 'Incident `#456` declared.'
        done()

  describe 'incident <id> update name: <name>', ->
    it 'should update an existing incident', (done) ->
      json = { name: "new name" }

      api.put('/incidents/456', json).reply(200, { data: { id: 456 } })

      helper.converse @robot, @user, '/incident 456 update name: new name', (envelope, response) ->
        assert.include response, 'Incident `#456` updated.'
        done()

    it 'should allow #123 as well as 123', (done) ->
      json = { name: "new name" }

      api.put('/incidents/456', json).reply(200, { data: { id: 456 } })

      helper.converse @robot, @user, '/incident #456 update name: new name', (envelope, response) ->
        assert.include response, 'Incident `#456` updated.'
        done()

    it 'should handle non-existing incidents', (done) ->
      json = { name: "new name" }

      api.put('/incidents/789', json).reply(404)

      helper.converse @robot, @user, '/incident 789 update name: new name', (envelope, response) ->
        assert.equal response, 'Incident `#789` does not exist.'
        done()

  describe 'incident <id> update message: <message>', ->
    it 'should update an existing incident', (done) ->
      json = { message: "new message" }

      api.put('/incidents/456', json).reply(200, { data: { id: 456 } })

      helper.converse @robot, @user, '/incident 456 update message: new message', (envelope, response) ->
        assert.include response, 'Incident `#456` updated.'
        done()

    it 'should allow #123 as well as 123', (done) ->
      json = { message: "new message" }

      api.put('/incidents/456', json).reply(200, { data: { id: 456 } })

      helper.converse @robot, @user, '/incident #456 update message: new message', (envelope, response) ->
        assert.include response, 'Incident `#456` updated.'
        done()

    it 'should handle non-existing incidents', (done) ->
      json = { message: "new message" }

      api.put('/incidents/789', json).reply(404)

      helper.converse @robot, @user, '/incident 789 update message: new message', (envelope, response) ->
        assert.equal response, 'Incident `#789` does not exist.'
        done()

  describe 'incident <id> enable', ->
    it 'should enable an existing incident', (done) ->
      json = { visible: 1 }

      api.put('/incidents/456', json).reply(200, { data: { id: 456 } })

      helper.converse @robot, @user, '/incident 456 enable', (envelope, response) ->
        assert.include response, 'Incident `#456` updated.'
        done()

    it 'should allow #123 as well as 123', (done) ->
      json = { visible: 1 }

      api.put('/incidents/456', json).reply(200, { data: { id: 456 } })

      helper.converse @robot, @user, '/incident #456 enable', (envelope, response) ->
        assert.include response, 'Incident `#456` updated.'
        done()

    it 'should handle non-existing incidents', (done) ->
      json = { visible: 1 }

      api.put('/incidents/789', json).reply(404)

      helper.converse @robot, @user, '/incident 789 enable', (envelope, response) ->
        assert.equal response, 'Incident `#789` does not exist.'
        done()

  describe 'incident <id> disable', ->
    it 'should disable an existing incident', (done) ->
      json = { visible: 0 }

      api.put('/incidents/456', json).reply(200, { data: { id: 456 } })

      helper.converse @robot, @user, '/incident 456 disable', (envelope, response) ->
        assert.include response, 'Incident `#456` updated.'
        done()

    it 'should allow #123 as well as 123', (done) ->
      json = { visible: 0 }

      api.put('/incidents/456', json).reply(200, { data: { id: 456 } })

      helper.converse @robot, @user, '/incident #456 disable', (envelope, response) ->
        assert.include response, 'Incident `#456` updated.'
        done()

    it 'should handle non-existing incidents', (done) ->
      json = { visible: 0 }

      api.put('/incidents/789', json).reply(404)

      helper.converse @robot, @user, '/incident 789 disable', (envelope, response) ->
        assert.equal response, 'Incident `#789` does not exist.'
        done()

  describe 'incident last <nb incidents>', ->
    it 'should list the last 2 incidents', (done) ->
      incidents = [
        { name: 'API is back!', human_status: 'Fixed' },
        { name: 'Issue on API has been identified', human_status: 'Identified' },
      ]

      api
        .get('/incidents?sort=created_at&order=desc&per_page=2')
        .reply(200, { data: incidents })

      helper.converse @robot, @user, '/incident last 2', (envelope, response) ->
        assert.equal response, [
          'API is back! (status = Fixed)',
          'Issue on API has been identified (status = Identified)'
        ].join '\n'
        done()

    it 'should list the last 5 incidents by default', (done) ->
      incidents = [
        { name: 'API is back 1!', human_status: 'Fixed' },
        { name: 'API is back 2!', human_status: 'Fixed' },
        { name: 'API is back 3!', human_status: 'Fixed' },
        { name: 'API is back 4!', human_status: 'Fixed' },
        { name: 'API is back 5!', human_status: 'Fixed' },
      ]

      api
        .get('/incidents?sort=created_at&order=desc&per_page=5')
        .reply(200, { data: incidents })

      helper.converse @robot, @user, '/incident last', (envelope, response) ->
        assert.equal response, [
          'API is back 1! (status = Fixed)',
          'API is back 2! (status = Fixed)',
          'API is back 3! (status = Fixed)',
          'API is back 4! (status = Fixed)',
          'API is back 5! (status = Fixed)',
        ].join '\n'
        done()

    it 'should say when there are no incidents', (done) ->
      api
        .get('/incidents?sort=created_at&order=desc&per_page=5')
        .reply(200, { data: [] })

      helper.converse @robot, @user, '/incident last 5', (envelope, response) ->
        assert.equal response, 'No incident found'
        done()

    it 'should deal with API errors', (done) ->
      api.get('/incidents?sort=created_at&order=desc&per_page=5').reply(500)

      helper.converse @robot, @user, '/incident last', (envelope, response) ->
        assert.equal response, 'The request to the API has failed (status code = 500)'
        done()
