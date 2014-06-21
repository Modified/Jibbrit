###
server.coffee
Jibbrit
- 2014-06-20: created for AngelHack 2014 TLV.
###

# Dependencies.
stylus=require 'stylus'
OpenTok=require 'opentok'

# OpenTok API.
OPENTOK_API_SECRET='1924d525ecc8ef5ffa70c05dae24037a7a88f921'
OPENTOK_API_KEY='44867752'

# Globals.
waiting_list={}

dictionary_things = [
	['Animal', 'חיה', 'animal']
	['Bread', 'לחם', 'pan']
	['Fire', 'אש', 'fuego']
	['Country', 'ארץ', 'país']
	['Day', 'יום', 'día']
	['Gold', 'זהב', 'oro']
	['Paper', 'נייר', 'papel']
	['Voice', 'קול', 'voz']
	['Word', 'מילה', 'palabra']
	['Sky', 'שמיים', 'cielo']
]

dictionary_operations = [
	['Get', 'השג', 'conseguir']
	['Give', 'תן', 'dar']
	['Go', 'לך', 'ir']
	['Make', 'עשה', 'hacer']
	['Put', 'שים', 'poner']
	['Take', 'קח', 'tomar']
	['Be', 'היה', 'ser']
	['Have', 'יש', 'tener']
	['Say', 'אמור', 'decir']
	['Will', 'מוכן', 'voluntad']
]

dictionary_qualities = [
	['Black', 'שחור', 'negro']
	['Cheap', 'זול', 'barato']
	['Clean', 'נקי', 'limpio']
	['Clear', 'שקוף', 'claro']
	['Strong', 'חזק', 'fuerte']
	['Happy', 'שמח', 'feliz']
	['Hard', 'קשה', 'duro']
	['Dark', 'אפל', 'oscuro']
	['Old', 'ישן', 'viejo']
	['Sad', 'עצוב', 'triste']
]

dictionaries=[dictionary_qualities, dictionary_operations, dictionary_things]

# OpenTok stuff.
generate_OT_keys=(cb)->
	console.log 'generate_OT_keys'
	# Server creates a session and two tokens for each conversation.
	ot=new OpenTok OPENTOK_API_KEY,OPENTOK_API_SECRET
	#console.log ot
	# Generate a basic session. Or you could use an existing session ID.
	ot.createSession (error,result)->
		if (error)
			console.log 'Error creating session:',error
			return
		console.log "Session ID: #{result.sessionId}"
		# Use the role value appropriate for the user:
		tokenOptions=role:'publisher'
		# tokenOptions.data = "username=bob";
		# Generate two tokens.
		token = ot.generateToken result.sessionId,tokenOptions
		cb result.sessionId,token

# Utilities.
pick_words = ->
  results = []
  for dictionary of dictionaries
    result = dictionary[Math.floor(Math.random() * dictionary.length)]
    results.push result  unless result of results
  results

uuid=->JSON.stringify Math.random()*1e16

# App!
require('zappajs') 3000,'0.0.0.0',->
	@use @app.logger
	@use static:__dirname+'/assets'
	@use 'partials'
	@enable 'default layout'
	@with css:'stylus'
	@io.set 'log level',1 # Shut up already! Lower verbosity.
	#@use @app.router

	@view index:->
		header ''
		section id:'setup',->
			label ->
				'Name'
				input type:'text',placeholder:'My name is…'
			input id:'mylang',type:'text',placeholder:'My language'
			input id:'herlang',type:'text',placeholder:'Language I want to learn'
			button -> 'Go'
		section id:'waiting',->
			div 'class':'spinner timer'
			p 'Waiting for other player to connect…'
		section id:'game',->
			button id:'lever'
			div 'class':'slot'
			div 'class':'slot'
			div 'class':'slot'
			video id:'myself'
			video id:'partner'
		section id:'give-score',->
			input type:'range'
		section id:'receive-score',->
			div ''
		section id:'next-round',->
			p ->'Next Round…'
			input type:'text',placeholder:'Wildcard'

	# Catchall route??? Eh, no.
	@get '/':->
		@render index:
			title:'Jibbrit'
			scripts:'''
				/zappa/Zappa-simple.js
				//static.opentok.com/webrtc/v2.2/js/opentok.min.js
				/app.js
				'''.match /[^\s]+/g
			stylesheets:'''
				//cdnjs.cloudflare.com/ajax/libs/font-awesome/4.1.0/css/font-awesome.min.css
				//css-spinners.com/css/spinner/timer.css
				'''.match /[^\s]+/g
			style: stylus.render '''
back=#0d4561
butt=#74c0e4
text=#74c0e4
act=#267094
pale=#b0dcf2

.hideinit
	display none

body
	font-family Ubuntu,sans-serif
	font-size large
	margin 0 auto
	background-color back
	color text

section
	display none

.OT_publisher
	display none
'''
	# Server side SIO events.
	@on 'find me a partner':->
		console.log 'find me a partner:',@data
		# Leave previous room, if was in any.
		r=@client.room
		if r
			@broadcast_to 'your partner left'
			@leave r
		# Try to match from waiting list.
		# Otherwise, add myself to waiting list.
		k="#{@data.mylang}:#{@data.herlang}"
		if not waiting_list[k]
			# Create room UUID.
			r=@client.room=uuid()
			@join r
			k="#{@data.herlang}:#{@data.mylang}"
			if k of waiting_list then waiting_list[k].push r else waiting_list[k]=[r]
			@ack 'please hold'
		else
			p=waiting_list[k].shift()
			@ack 'found partner in room '+p
			@join p
			# Generate OT keys.
			generate_OT_keys (s,t)=>
				@broadcast_to p,'start playing',[s,t]

	# Client side code.
	@client '/app.js':->
		@connect()

		# Client side SIO events.
		@on 'your partner left':->
			console.log 'abandoned:',@data

		@on 'start playing':->
			console.log 'playing room:',@data
			# Client publishes and subscribes on the session.
			OPENTOK_API_KEY='44867752'
			session=OT.initSession OPENTOK_API_KEY,@data[0]
			session.connect @data[1],(error)->
				publisher=OT.initPublisher()
				# the target is the element (div) to be replaced by video
				session.publish publisher,'#myself'

			session.on 'streamCreated',(ev)->
				session.subscribe ev.stream,'#partner'
			$ '#waiting,#game'
			.toggle()


		$ =>
			$ 'html'
			.addClass 'jib'
			$ 'head'
			.append $ '<meta name="viewport" content="width=device-width,initial-scale=1">'
			sect=$ 'section'

			# Show setup page!
			$ '#setup'
			.show()
			$ '#setup button'
			.click (ev)=>
				ev.preventDefault()
				$ '#setup,#waiting'
				.toggle()
				# What's in the form?
				d=mylang:$('#mylang').val(),herlang:$('#herlang').val()
				console.log d
				# Tell server to find me a matching partner.
				@emit 'find me a partner',d,(r)->
					console.log 'find me a partner ack:',r

#$('body').on 'click','button.trinket',(ev)->
#	total+=parseInt(($(ev.target).text().match /\$(\d+)/)[1])
#	$('.pay').html "<img src=\"/paypal.jpg\"> Purchase total: $#{total}.<sup>00</sup>"
#	false
