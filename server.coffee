###
server.coffee
Jibbrit
- 2014-06-20: created for AngelHack 2014 TLV.
###

# Dependencies.
stylus=require 'stylus'

# Globals.
waiting_list={}

# Functions.
pick_3=(large_list)->
	results=[]
	until results.length is 3
		result=large_list[Math.floor(Math.random()*large_list.length)]
		results.push result unless result of results
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
		k="#{@data.mylang}:#{@data.herlang}"
		if waiting_list[k]
			p=waiting_list[k].shift()
			@ack 'found parner in room '+p
			@join p
			@emit 'start playing',p
			@broadcast_to 'start playing',p
		# Otherwise, add myself to waiting list.
		else
			# Create room UUID.
			r=@client.room=uuid()
			@join r
			k="#{@data.herlang}:#{@data.mylang}"
			if k of waiting_list then waiting_list[k].push r else waiting_list[k]=[r]
			@ack 'please hold'

	# Client side code.
	@client '/app.js':->
		@connect()

		# Client side SIO events.
		@on 'start playing':->
			console.log 'playing room:',@data
			$ '#waiting,#game'
			.toggle()
		@on 'your partner left':->
			console.log 'abandoned:',@data

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
