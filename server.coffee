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
			img src:'/splash.png'
			label style:'display:none',->
				'Name'
				input type:'text',placeholder:'My name is…'
			input id:'mylang',type:'text',placeholder:'My language'
			input id:'herlang',type:'text',placeholder:'Language I want to learn'
			button -> 'Go'
		section id:'waiting',->
			div 'class':'spinner timer'
			p 'Looking for a match…'
		section id:'game',->
			button id:'play',->
				'Play!'
			span id:'slot-machine',->
				div 'class':'wrapper',->
					div 'class':'slot'
				div 'class':'wrapper',->
					div 'class':'slot'
				div 'class':'wrapper',->
					div 'class':'slot'
			div id:'countdown'
			div id:'total-score'
			section id:'give-score',->
				input type:'range'
			section id:'receive-score',->
				div ''
			section id:'next-round',->
				p ->'Next Round…'
				input type:'text',placeholder:'Wildcard'
		video id:'myself'
		video id:'partner'

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
				//fonts.googleapis.com/css?family=Changa+One|Inder
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
	font-family Inder,sans-serif
	font-size 1.3rem
	margin 0 auto
	background-image url(/bg.jpg)
	background-repeat no-repeat
	background-size cover
	background-attachment fixed
	color black

section
	display none
	margin 1em auto
	max-width 30em
	position relative

#slot-machine
	display inline-block

.wrapper
	margin 1em
	display inline-block
	height 6em
	overflow hidden
	background white
	font-family "Changa One"
	font-size 1.8rem

	span
		display block
		margin 0.5em

#setup img
	margin 0 auto
	display block

#game
	text-align right
	padding-top 1em

input,
button
	display block
	margin 1em auto
	padding 0.5em
	outline none
	border none
	font-size 1.3rem
	background-color #d94735
	border-radius 1em
button
	font-size 1.8rem

#countdown
	position  absolute
	top  0
	right  0
	background  red
	font-family "Changa One"

.OT_subscriber
	position fixed
	top 1em
	left 1em

.OT_publisher
	position fixed
	bottom 1em
	left 1em
	z-index -1
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
			if k of waiting_list then waiting_list[k].push(r) else waiting_list[k]=[r]
			@ack 'please hold'
		else
			p=@client.room=waiting_list[k].shift()
			@ack 'found partner in room '+p
			@join p
			# Generate OT keys.
			generate_OT_keys (s,t)=>
				@broadcast_to p,'start playing',[s,t]

	@on 'end round':->
		@broadcast_to @client.room,'end round'

	@on 'picked word':->
		@broadcast_to @client.room,'picked word',@data

	# Client side code.
	@client '/app.js':->
		@connect()

		pick_words=->
			[
				['אנימל', 'חיה', 'animal']
				['דסיר', 'אמור', 'decir']
				['נגרו', 'שחור', 'negro']
			]

		# Dictionary.
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
			start_round()

		@on 'end round':->
			window.im_student=not window.im_student
			start_round()

		# Slot roulette.
		spin_slot=(i,w)=>
			#console.log i,w
			@emit 'picked word',[i,w]

		cherries=['Bread','לחם','pan','Fire','אש','fuego','Country','ארץ','país','Day','יום','día','Gold','זהב','oro','Paper','נייר','papel','Voice','קול','voz','Word','מילה','palabra','Sky','שמיים','cielo']

		@on 'picked word':->
			[i,w]=@data
			console.log i,w
			ss=$ '.slot'
			# Randomize.
			s=$ ss[i]
			s.empty()
			cherries.forEach (v)->
				s.append($('<span>').text(v))
			# Animate.
			s
			.stop()
			.css 'margin-top':'-999px'
			.animate({'margin-top':'0'},5999,'swing',->
				# Show picked word.
				s
				.empty()
				.append($('<span>').text(w[0]))
				.append($('<span>').text(w[1]))
				.append($('<span>').text(w[2]))
			)

		start_countdown= =>
			count_down= =>
				countdown -=1/Math.PI
				if countdown<0
					clearInterval int
					@emit 'end round'
				else $('#countdown').text countdown

			window.countdown=20.0
			$('#countdown').text countdown
			int=setInterval count_down,1e3/Math.PI

		# Game logic.
		start_round=->
			$ '#game'
			.toggleClass 'student',im_student
			$ '#play'
			.toggle im_student

		$ =>
			$ 'html'
			.addClass 'jib'
			$ 'head'
			.append $ '<meta name="viewport" content="width=device-width,initial-scale=1">'
			sect=$ 'section'

			# Show setup page!
			$ 'body'
			.css background:'none'
			$ '#setup'
			.show()
			$ '#setup button'
			.click (ev)=>
				ev.preventDefault()
				$ '#setup,#waiting'
				.toggle()
				$('body').removeAttr('style')
				# What's in the form?
				d=mylang:$('#mylang').val(),herlang:$('#herlang').val()
				console.log d
				# Tell server to find me a matching partner.
				@emit 'find me a partner',d,(r)->
					console.log 'find me a partner ack:',r
					window.im_student=r is 'please hold'
					console.log 'im_student:',im_student

			$ '#play'
			.click (ev)->
				ev.preventDefault()
				if im_student
					ws=pick_words()
					console.log ws
					spin_slot i,ws[i] for i in [0..2]
				start_countdown()

#$('body').on 'click','button.trinket',(ev)->
#	total+=parseInt(($(ev.target).text().match /\$(\d+)/)[1])
#	$('.pay').html "<img src=\"/paypal.jpg\"> Purchase total: $#{total}.<sup>00</sup>"
#	false
