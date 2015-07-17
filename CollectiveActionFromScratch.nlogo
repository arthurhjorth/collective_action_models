extensions [table cf goo]


breed [ cows cow ]  ;; creation controlled by farmers
breed [ farmers farmer ] ;; created and controlled by clients
breed [ fences fence]

globals [
  ;; make some tables for saving this stuff for later.
  farmer-actions
  
  average-cows-per-player ;; the number of cows per average per player that the field can sustain
  
  max-grass ;; the max amount of grass on a patch
  cows-eat ;; the amount cows eat per turn
  cows-max-energy ;; the amount that cows can store
  cows-metabolize-week ;; the amount that cows metabolize per day
  grass-regrow ;; the amount that grass grows back
  fence-fix-points
  shepherd-bonus ; the extra amount of food cows will try to eat if they are being shepherded
  
  edge-patches ;; all patches along the edge. might as well just put them in one patchset to begin with
  
  common-pool-bank ;; this is money that people have pooled together
  
  
  ;; some plotting lists
  known-grass-amounts
  total-milk-production
  known-fence-states
  money-in-the-bank
]

cows-own
[
  owner             ;; the user-id of the farmer who owns the goat
  energy            ;; amount the cow has eaten this round
]

farmers-own
[
  user-id            ;; unique user-id, input by the client when they log in,
                     ;; to identify each student turtle
  milk-production-list       ;; list of each days' revenue collection
  donations-list
  
  say-will-do-today
  will-cheat-today?  ;; will they defect today
  money
]

fences-own [
 durability 
]

patches-own[
  grass
  grass-known
  water
]

to run-a-week
  ;; only run the week if everybody has decided what to do
  let undecided farmers with [will-cheat-today? = 0 or say-will-do-today = 0]
  if any? undecided [show (word [user-id] of undecided " still undecided.") stop]
  
  color-student-cows 
  ;; we can figure out how to do the visualization later. But here are the options:
  ;; I wonder if we should actually let people do other things too. They could decide to inspect fences without telling anyone
  ;; so that they can catch defectors. 
  ask farmers [do-weekly-action]
  ;; all cows graze. We do this to make sure everybody's cows get an equal chance at eating,
  ;; and to smoothe out movement animation
  repeat 7 [ask cows [graze]]
  ask cows [metabolize-and-maybe-die]
  
  ;; calculate how much milk they get (we need a better function for this, I think)
  ask farmers [sell-milk]
 

  ask farmers
  [
   hubnet-send user-id "$" money
   hubnet-send user-id "# of Cows" (count my-cows)
  ]
  
  ;; fences deteriorate 
  ask fences [set durability min (list durability (durability - random 25))]
  
  ;; grass regrows
  ask grass-patches [
    grow-grass 
    recolor-grass ;; we may not want to do this unless people "survey" the grass
  ]  
  
  tick
  ;; and reset farmers. Maybe shouldn't reset yet. We need to collect statistics, and students need to see the result of what happened
  ask farmers [reset-farmer]
end


to do-weekly-action
  (
    cf:match say-will-do-today
    cf:= "Say: Repair Fences" [fix-fences]
    cf:= "Say: Inspect Fences" [inspect-fences]
    )
end


to color-student-cows
  ask farmers [ hubnet-send-override user-id my-cows "color" [red] ]
end

to metabolize-and-maybe-die
  set energy energy - cows-metabolize-week
  if energy < 0 [
    show (word owner "just lost a cow to starvation.")
    die
  ]
end

to sell-milk
  let total-production [energy] of my-cows
  let profit  sum total-production
  set milk-production-list fput profit milk-production-list 
  set money money + profit
  set milk-production-list lput profit milk-production-list
end


to fix-fences
  let fix-points fence-fix-points
  while [fix-points > 0 and any? fences with [durability < 100]] [    
    let most-broken-fence min-one-of fences [durability]
    move-to most-broken-fence
    let fix-diff 100 - [durability] of most-broken-fence
    ifelse fix-diff < fix-points 
    [
      ask most-broken-fence [set durability 100]
      set fix-points fix-points - fix-diff
    ]
    [
      ask most-broken-fence [set durability durability + fix-points]
      set fix-points 0
    ]
  ]  
end

to inspect-fences
  ask fences [set label durability]
end
  
to graze
  eat
  cow-move
end

to cow-move
  ;; cows wander around randomly
  rt random 30
  lt random 30
  ;; if there's a fence in front of them, turn around
  if [ any? fences-here with [durability > 0]] of patch-ahead 1 [rt 180]  
  ;; if they end up on an edge patch, they die
  if member? patch-here edge-patches [
    show (word owner " just lost a cow because the fences were broke.")
    die]
  
  fd 1
end

to eat
  ;; let cows eat 20% more if their owner shepherds
  let my-max-eat ifelse-value [shepherding-this-week?] of owner [cows-eat * (1 + shepherd-bonus)] [cows-eat]
  let stomach-space-left cows-max-energy - energy
  let eaten-amount min (list stomach-space-left grass cows-eat)
  show eaten-amount
  set energy energy  + eaten-amount
  set grass grass - eaten-amount
end
  
  
  
to setup
  ca
  setup-globals
  setup-world
  hubnet-reset
  reset-ticks
end


to go
  hubnet-broadcast "Action" "Choose what to do today"
end






to setup-world
  set edge-patches patches with [pxcor = min-pxcor or pxcor = max-pxcor or pycor = min-pycor or pycor = max-pycor]
  ask patches [set grass (max-grass / 3) + random-float (max-grass * 2 / 3 ) recolor-grass]
  ask fences [die]
  ask edge-patches [sprout-fences 1 [set shape "fence" set heading 0 set color brown set durability 50 + random 50]]
end  

to setup-globals
  set farmer-actions table:make
  scale-vars-for-n-players
end


to scale-vars-for-n-players
  let no-of-farmers length hubnet-clients-list
    ;; extra food that cows will try to eat if they are being shepherded
  set shepherd-bonus .2
  ;; 961 patches with grass growing on it.
  ;; we need to balance how fast grass grows back, how quickly fences deteriorate, and how how grass
  ;; can be on each patch so that the world automatically can support N people. (N = no-of-farmers.)
  ;; Let's assume that people start with three cows, and we want the game to go on for "a while". Let's say that 
  ;; at its base level, the world can support 6 cows per player.
  ;; let's just say that a cow needs 7 energy to sustain itself for a week.
  ;; in that case, the entire system (without extra work towards it) should produce
  ;; 7 * 6 * n-of-farmers, or 42 per player, per week. That's an odd number for this just because it would mean that
  ;; a lot of the patches would not produce anything or they would produce a fraction of an energy's worth of food
  ;; so maybe we should say 70 per week? that will make the numbers more on an order that makes sense.
  set cows-metabolize-week 70
  ;; cows metabolize 10 per day, and they should be able to eat as much as they metabolize plus... 50? let's try that  
  set cows-eat cows-metabolize-week * 1.5 / 7  ;; the amount cows eat per turn
  ;; let's say that cows can eat at most 33% of the grass on a patch per day, so that means max-grass is 45
  set max-grass cows-eat * 3
  ;; let's also say that a cow can store enough energy to not eat at all for one week. That means they can store a total of 
  ;; 7 * 10  = 70.
  set cows-max-energy cows-metabolize-week ;; the amount that cows can store
  ;; if the whole system should have a base-carrying capacity of 700 * 6 = 4200
  set average-cows-per-player 6
  set grass-regrow ( no-of-farmers * average-cows-per-player * cows-metabolize-week) / count patches with [not any? fences-here] ;; the amount that grass grows back
  

  ;; there are 128 fences, each with 100 points of durability
  ;; we should scale how many points they get to fix them with, rather than the durability decline. in the case of the former
  ;; it will just get to the point where fences need fixing sooner (if I am running this correctly in my head)
  ;; So: 128 fences declining by up to 25 points each turn, with a mean of 12.5
  ;; 128 * 12.5 = 1600.
  ;; we want one fifth of players fixing fences all the time, so
  ;; if no one has logged in, don't do this or we get division by zero
  if length hubnet-clients-list > 0 [
    set fence-fix-points 5 * count fences / length hubnet-clients-list
  ]
  
end


to listen-to-clients
  while [ hubnet-message-waiting? ]
  [
    hubnet-fetch-message
    (cf:cond
     cf:case [ hubnet-enter-message? ] [ add-farmer hubnet-message-source ]
     cf:case [hubnet-exit-message?] [kill-farmer hubnet-message-source]
     cf:else [ do-command hubnet-message-source hubnet-message-tag])
  ]
end

to add-farmer [message-source]
  table:put farmer-actions message-source table:make
  goo:set-chooser-items "fine-who" sort hubnet-clients-list
  set fine-who item 0 sort hubnet-clients-list
  create-farmers 1 [
    set user-id message-source
    ht
    set money 50
    set color one-of base-colors
    set milk-production-list []
    hatch-cows 3 [ set owner myself set shape "cow" set color [color] of myself set energy 10 move-to one-of grass-patches st]
    reset-farmer
  ]
end

to kill-farmer [message-source]
  ask farmers with [user-id = message-source ] [die]
end

to do-command [source tag]
  ask farmers with [user-id = source] [
    show tag
    let update-client-display true
    ;; ifelse/case here for different kinds
    (cf:cond 
      cf:case [member? "Say:" tag] [set say-will-do-today tag print-who-says-what]
      cf:case [tag = "Do: What I Said"] [set will-cheat-today? false]
      cf:case [tag = "Do: Lie, and shepherd Cows"] [set will-cheat-today? true]
      cf:else [ set update-client-display false ]
    )
    if (update-client-display) [
      show (word "my will-cheat flag is " will-cheat-today?)
      let suffix " (the truth)"
      if will-cheat-today? = true [ set suffix " (a lie)" ]
      hubnet-send user-id "Action" (word say-will-do-today suffix)
    ]
  ]
  
end

to show-who-says [astring] 
  let the-users sort [user-id] of farmers with [say-will-do-today = astring]
    output-print (word astring " (" length the-users ")")
    output-print ifelse-value (length the-users > 0) [the-users] ["Nobody"]
    output-print ""
end

to print-who-says-what
  clear-output
  show-who-says "Say: Repair Fences" 
  show-who-says "Say: Inspect Fences" 
  show-who-says "Say: Shepherd my Cows"
end

to reset-farmer
  set say-will-do-today 0
  set will-cheat-today? 0
end

to grow-grass
  set grass min (list max-grass (grass + grass-regrow))
end


to recolor-grass
  set pcolor scale-color green grass -2 (max-grass * 1.3)
end

to-report my-cows  ;; farmer procedure, returns agentset of their cows
    report cows with [owner = myself]
end

to-report grass-patches 
  report patches with [shade-of? pcolor   green]
end

;; farmer reporter. will they shepherd this week
to-report shepherding-this-week?
  report say-will-do-today = "Say: Shepherd my Cows" or will-cheat-today?
end

;; AH: OK, we'll just do one large table full of 'action tables'. An
;; action table contains the hubnet-id, the type of action, the week it happened, and a value
;; AH: thinking about it, i'm not even sure this is worth it. fuck it, we'll do it live. with lists.
to log-player-action [hubnet-id action value]
  set farmer-actions lput (list hubnet-id ticks action value) farmer-actions
end

;; plotting procedures
to do-plot-1
  set-current-plot "Plot 1"
  clear-plot
  let the-list get-plot-list plot-1
  foreach n-values (length the-list - 1) [?][
    plotxy ? item ? the-list
  ]
end

;; plotting procedures
to do-plot-2
  set-current-plot "Plot 2"
  let the-list get-plot-list plot-2
  foreach n-values (length the-list - 1) [?][
    plotxy ? item ? the-list
  ]
end


to-report get-plot-list [plot-list-description]
  report (
    cf:match-value plot-list-description
    cf:= "Amount of grass (as far as we know)" [known-grass-amounts]
    cf:= "Mean state of fences (as far as we know)" [known-fence-states]
    cf:= "Total Milk Production" [total-milk-production]
    cf:= "Money in Bank" [money-in-the-bank]
    cf:= "How many repaired fences" []
    cf:= "How many sowed grass"[]
    )
end

to fine-them
  let the-farmer one-of farmers with [user-id = fine-who]
  ask the-farmer [
    ifelse money >= fine-amount [
      set money money - fine-amount
      set common-pool-bank common-pool-bank + fine-amount
    ]
    [
      show (word user-id " does not have $ " fine-amount "!")
    ]
  ]
  
end
@#$#@#$#@
GRAPHICS-WINDOW
155
10
594
470
16
16
13.0
1
10
1
1
1
0
0
0
1
-16
16
-16
16
1
1
1
Week
30.0

OUTPUT
600
45
880
345
12

BUTTON
10
10
142
43
NIL
listen-to-clients
T
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
10
85
112
118
NIL
run-a-week
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
10
45
135
78
NIL
setup
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

MONITOR
600
345
770
390
Shared Money
common-pool-bank
0
1
11

SLIDER
600
385
760
418
fine-amount
fine-amount
0
100
17
1
1
$
HORIZONTAL

CHOOSER
600
420
760
465
fine-who
fine-who
"Local 1" "Local 2" "Local 3" "Local 4" "Local 5"
0

CHOOSER
885
10
1177
55
plot-1
plot-1
"Amount of grass (as far as we know)" "Mean state of fences (as far as we know)" "Total Milk Production" "Money in Bank" "How many repaired fences" "How many sowed grass"
0

PLOT
885
55
1345
195
Plot 1
NIL
NIL
0.0
10.0
0.0
10.0
true
false
"" ""
PENS
"default" 1.0 0 -16777216 true "" "plot count turtles"

PLOT
885
195
1345
335
Plot 2
NIL
NIL
0.0
10.0
0.0
10.0
true
false
"" ""
PENS
"default" 1.0 0 -16777216 true "" "plot count turtles"

CHOOSER
885
335
1177
380
plot-2
plot-2
"Amount of grass (as far as we know)" "Mean state of fences (as far as we know)" "Total Milk Production" "Money in Bank" "How many repaired fences" "How many sowed grass"
1

BUTTON
1175
335
1345
380
NIL
do-plot-2
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
1175
10
1345
55
NIL
do-plot-1
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
760
395
885
465
NIL
fine-them
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

@#$#@#$#@
## WHAT IS IT?

This model is inspired by Elinor Ostrom's work on how people manage resource systems and set up so-called institutions for collective action.

She positioned her work in opposition to The Tragedy of the Commons (TOC). 

## HOW IT WORKS



## HOW TO USE IT

(how to use the model, including a description of each of the items in the Interface tab)

## THINGS TO NOTICE

(suggested things for the user to notice while running the model)

## THINGS TO TRY

(suggested things for the user to try to do (move sliders, switches, etc.) with the model)

## EXTENDING THE MODEL

(suggested things to add or change in the Code tab to make the model more complicated, detailed, accurate, etc.)

## NETLOGO FEATURES

(interesting or unusual features of NetLogo that the model uses, particularly in the Code tab; or where workarounds were needed for missing features)

## RELATED MODELS

(models in the NetLogo Models Library and elsewhere which are of related interest)

## CREDITS AND REFERENCES

(a reference to the model's URL on the web if it has one, as well as any other necessary credits, citations, and links)
@#$#@#$#@
default
true
0
Polygon -7500403 true true 150 5 40 250 150 205 260 250

airplane
true
0
Polygon -7500403 true true 150 0 135 15 120 60 120 105 15 165 15 195 120 180 135 240 105 270 120 285 150 270 180 285 210 270 165 240 180 180 285 195 285 165 180 105 180 60 165 15

arrow
true
0
Polygon -7500403 true true 150 0 0 150 105 150 105 293 195 293 195 150 300 150

box
false
0
Polygon -7500403 true true 150 285 285 225 285 75 150 135
Polygon -7500403 true true 150 135 15 75 150 15 285 75
Polygon -7500403 true true 15 75 15 225 150 285 150 135
Line -16777216 false 150 285 150 135
Line -16777216 false 150 135 15 75
Line -16777216 false 150 135 285 75

bug
true
0
Circle -7500403 true true 96 182 108
Circle -7500403 true true 110 127 80
Circle -7500403 true true 110 75 80
Line -7500403 true 150 100 80 30
Line -7500403 true 150 100 220 30

butterfly
true
0
Polygon -7500403 true true 150 165 209 199 225 225 225 255 195 270 165 255 150 240
Polygon -7500403 true true 150 165 89 198 75 225 75 255 105 270 135 255 150 240
Polygon -7500403 true true 139 148 100 105 55 90 25 90 10 105 10 135 25 180 40 195 85 194 139 163
Polygon -7500403 true true 162 150 200 105 245 90 275 90 290 105 290 135 275 180 260 195 215 195 162 165
Polygon -16777216 true false 150 255 135 225 120 150 135 120 150 105 165 120 180 150 165 225
Circle -16777216 true false 135 90 30
Line -16777216 false 150 105 195 60
Line -16777216 false 150 105 105 60

car
false
0
Polygon -7500403 true true 300 180 279 164 261 144 240 135 226 132 213 106 203 84 185 63 159 50 135 50 75 60 0 150 0 165 0 225 300 225 300 180
Circle -16777216 true false 180 180 90
Circle -16777216 true false 30 180 90
Polygon -16777216 true false 162 80 132 78 134 135 209 135 194 105 189 96 180 89
Circle -7500403 true true 47 195 58
Circle -7500403 true true 195 195 58

circle
false
0
Circle -7500403 true true 0 0 300

circle 2
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240

cow
false
0
Polygon -7500403 true true 200 193 197 249 179 249 177 196 166 187 140 189 93 191 78 179 72 211 49 209 48 181 37 149 25 120 25 89 45 72 103 84 179 75 198 76 252 64 272 81 293 103 285 121 255 121 242 118 224 167
Polygon -7500403 true true 73 210 86 251 62 249 48 208
Polygon -7500403 true true 25 114 16 195 9 204 23 213 25 200 39 123

cylinder
false
0
Circle -7500403 true true 0 0 300

dot
false
0
Circle -7500403 true true 90 90 120

face happy
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 255 90 239 62 213 47 191 67 179 90 203 109 218 150 225 192 218 210 203 227 181 251 194 236 217 212 240

face neutral
false
0
Circle -7500403 true true 8 7 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Rectangle -16777216 true false 60 195 240 225

face sad
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 168 90 184 62 210 47 232 67 244 90 220 109 205 150 198 192 205 210 220 227 242 251 229 236 206 212 183

fence
false
0
Line -6459832 false 30 255 30 105
Line -6459832 false 150 240 150 75
Line -6459832 false 255 225 255 60
Line -6459832 false 15 135 285 90
Line -6459832 false 15 165 285 120
Line -6459832 false 15 195 285 150
Line -6459832 false 15 225 285 180

fish
false
0
Polygon -1 true false 44 131 21 87 15 86 0 120 15 150 0 180 13 214 20 212 45 166
Polygon -1 true false 135 195 119 235 95 218 76 210 46 204 60 165
Polygon -1 true false 75 45 83 77 71 103 86 114 166 78 135 60
Polygon -7500403 true true 30 136 151 77 226 81 280 119 292 146 292 160 287 170 270 195 195 210 151 212 30 166
Circle -16777216 true false 215 106 30

flag
false
0
Rectangle -7500403 true true 60 15 75 300
Polygon -7500403 true true 90 150 270 90 90 30
Line -7500403 true 75 135 90 135
Line -7500403 true 75 45 90 45

flower
false
0
Polygon -10899396 true false 135 120 165 165 180 210 180 240 150 300 165 300 195 240 195 195 165 135
Circle -7500403 true true 85 132 38
Circle -7500403 true true 130 147 38
Circle -7500403 true true 192 85 38
Circle -7500403 true true 85 40 38
Circle -7500403 true true 177 40 38
Circle -7500403 true true 177 132 38
Circle -7500403 true true 70 85 38
Circle -7500403 true true 130 25 38
Circle -7500403 true true 96 51 108
Circle -16777216 true false 113 68 74
Polygon -10899396 true false 189 233 219 188 249 173 279 188 234 218
Polygon -10899396 true false 180 255 150 210 105 210 75 240 135 240

house
false
0
Rectangle -7500403 true true 45 120 255 285
Rectangle -16777216 true false 120 210 180 285
Polygon -7500403 true true 15 120 150 15 285 120
Line -16777216 false 30 120 270 120

leaf
false
0
Polygon -7500403 true true 150 210 135 195 120 210 60 210 30 195 60 180 60 165 15 135 30 120 15 105 40 104 45 90 60 90 90 105 105 120 120 120 105 60 120 60 135 30 150 15 165 30 180 60 195 60 180 120 195 120 210 105 240 90 255 90 263 104 285 105 270 120 285 135 240 165 240 180 270 195 240 210 180 210 165 195
Polygon -7500403 true true 135 195 135 240 120 255 105 255 105 285 135 285 165 240 165 195

line
true
0
Line -7500403 true 150 0 150 300

line half
true
0
Line -7500403 true 150 0 150 150

pentagon
false
0
Polygon -7500403 true true 150 15 15 120 60 285 240 285 285 120

person
false
0
Circle -7500403 true true 110 5 80
Polygon -7500403 true true 105 90 120 195 90 285 105 300 135 300 150 225 165 300 195 300 210 285 180 195 195 90
Rectangle -7500403 true true 127 79 172 94
Polygon -7500403 true true 195 90 240 150 225 180 165 105
Polygon -7500403 true true 105 90 60 150 75 180 135 105

plant
false
0
Rectangle -7500403 true true 135 90 165 300
Polygon -7500403 true true 135 255 90 210 45 195 75 255 135 285
Polygon -7500403 true true 165 255 210 210 255 195 225 255 165 285
Polygon -7500403 true true 135 180 90 135 45 120 75 180 135 210
Polygon -7500403 true true 165 180 165 210 225 180 255 120 210 135
Polygon -7500403 true true 135 105 90 60 45 45 75 105 135 135
Polygon -7500403 true true 165 105 165 135 225 105 255 45 210 60
Polygon -7500403 true true 135 90 120 45 150 15 180 45 165 90

sheep
false
15
Circle -1 true true 203 65 88
Circle -1 true true 70 65 162
Circle -1 true true 150 105 120
Polygon -7500403 true false 218 120 240 165 255 165 278 120
Circle -7500403 true false 214 72 67
Rectangle -1 true true 164 223 179 298
Polygon -1 true true 45 285 30 285 30 240 15 195 45 210
Circle -1 true true 3 83 150
Rectangle -1 true true 65 221 80 296
Polygon -1 true true 195 285 210 285 210 240 240 210 195 210
Polygon -7500403 true false 276 85 285 105 302 99 294 83
Polygon -7500403 true false 219 85 210 105 193 99 201 83

square
false
0
Rectangle -7500403 true true 30 30 270 270

square 2
false
0
Rectangle -7500403 true true 30 30 270 270
Rectangle -16777216 true false 60 60 240 240

star
false
0
Polygon -7500403 true true 151 1 185 108 298 108 207 175 242 282 151 216 59 282 94 175 3 108 116 108

target
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240
Circle -7500403 true true 60 60 180
Circle -16777216 true false 90 90 120
Circle -7500403 true true 120 120 60

tree
false
0
Circle -7500403 true true 118 3 94
Rectangle -6459832 true false 120 195 180 300
Circle -7500403 true true 65 21 108
Circle -7500403 true true 116 41 127
Circle -7500403 true true 45 90 120
Circle -7500403 true true 104 74 152

triangle
false
0
Polygon -7500403 true true 150 30 15 255 285 255

triangle 2
false
0
Polygon -7500403 true true 150 30 15 255 285 255
Polygon -16777216 true false 151 99 225 223 75 224

truck
false
0
Rectangle -7500403 true true 4 45 195 187
Polygon -7500403 true true 296 193 296 150 259 134 244 104 208 104 207 194
Rectangle -1 true false 195 60 195 105
Polygon -16777216 true false 238 112 252 141 219 141 218 112
Circle -16777216 true false 234 174 42
Rectangle -7500403 true true 181 185 214 194
Circle -16777216 true false 144 174 42
Circle -16777216 true false 24 174 42
Circle -7500403 false true 24 174 42
Circle -7500403 false true 144 174 42
Circle -7500403 false true 234 174 42

turtle
true
0
Polygon -10899396 true false 215 204 240 233 246 254 228 266 215 252 193 210
Polygon -10899396 true false 195 90 225 75 245 75 260 89 269 108 261 124 240 105 225 105 210 105
Polygon -10899396 true false 105 90 75 75 55 75 40 89 31 108 39 124 60 105 75 105 90 105
Polygon -10899396 true false 132 85 134 64 107 51 108 17 150 2 192 18 192 52 169 65 172 87
Polygon -10899396 true false 85 204 60 233 54 254 72 266 85 252 107 210
Polygon -7500403 true true 119 75 179 75 209 101 224 135 220 225 175 261 128 261 81 224 74 135 88 99

wheel
false
0
Circle -7500403 true true 3 3 294
Circle -16777216 true false 30 30 240
Line -7500403 true 150 285 150 15
Line -7500403 true 15 150 285 150
Circle -7500403 true true 120 120 60
Line -7500403 true 216 40 79 269
Line -7500403 true 40 84 269 221
Line -7500403 true 40 216 269 79
Line -7500403 true 84 40 221 269

wolf
false
0
Polygon -16777216 true false 253 133 245 131 245 133
Polygon -7500403 true true 2 194 13 197 30 191 38 193 38 205 20 226 20 257 27 265 38 266 40 260 31 253 31 230 60 206 68 198 75 209 66 228 65 243 82 261 84 268 100 267 103 261 77 239 79 231 100 207 98 196 119 201 143 202 160 195 166 210 172 213 173 238 167 251 160 248 154 265 169 264 178 247 186 240 198 260 200 271 217 271 219 262 207 258 195 230 192 198 210 184 227 164 242 144 259 145 284 151 277 141 293 140 299 134 297 127 273 119 270 105
Polygon -7500403 true true -1 195 14 180 36 166 40 153 53 140 82 131 134 133 159 126 188 115 227 108 236 102 238 98 268 86 269 92 281 87 269 103 269 113

x
false
0
Polygon -7500403 true true 270 75 225 30 30 225 75 270
Polygon -7500403 true true 30 75 75 30 270 225 225 270

@#$#@#$#@
NetLogo 5.2.0-LS1
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
BUTTON
5
95
170
128
Say: Repair Fences ($20)
NIL
NIL
1
T
OBSERVER
NIL
NIL

BUTTON
5
130
170
163
Say: Shepherd my Cows
NIL
NIL
1
T
OBSERVER
NIL
NIL

BUTTON
185
95
310
128
Say: Inspect Fences
NIL
NIL
1
T
OBSERVER
NIL
NIL

BUTTON
5
195
207
228
Do: Lie, and shepherd Cows
NIL
NIL
1
T
OBSERVER
NIL
NIL

MONITOR
5
305
95
354
# of Cows
NIL
0
1

MONITOR
100
305
190
354
$
NIL
2
1

BUTTON
200
305
320
355
Buy Cow ($100)
NIL
NIL
1
T
OBSERVER
NIL
NIL

VIEW
340
15
740
415
0
0
0
1
1
1
1
1
0
1
1
1
-16
16
-16
16

MONITOR
10
10
325
59
Action
NIL
0
1

TEXTBOX
10
75
160
93
What you say you will do
11
0.0
1

TEXTBOX
10
175
160
193
Will you cheat?
11
0.0
1

TEXTBOX
5
285
155
303
Click here to buy cows
11
0.0
1

BUTTON
210
195
335
228
Do: What I Said
NIL
NIL
1
T
OBSERVER
NIL
NIL

SLIDER
5
360
190
393
money-to-shared-bank
money-to-shared-bank
0
100
50
1
1
NIL
HORIZONTAL

BUTTON
200
360
320
393
Donate
NIL
NIL
1
T
OBSERVER
NIL
NIL

BUTTON
185
130
310
163
Say: Sow Grass ($20)
NIL
NIL
1
T
OBSERVER
NIL
NIL

@#$#@#$#@
default
0.0
-0.2 0 0.0 1.0
0.0 1 1.0 0.0
0.2 0 0.0 1.0
link direction
true
0
Line -7500403 true 150 150 90 180
Line -7500403 true 150 150 210 180

@#$#@#$#@
1
@#$#@#$#@
