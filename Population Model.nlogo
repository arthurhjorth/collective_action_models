;; Interpreting Congestion Charge ;;
;; This model is based on Michael Freeden s example 
;; The purpose of this model is to show the ambiguity of political concepts such as public goods
;; and the interpretation of policies.
;; TODOS: price sensitivity 

extensions [gradient]

globals [
  
  global-pollution-per-day               ;; pollution variable
  travel-time-added                      ;; traffic congestion, how congested is traffic. 
                                         ;; this variable adds itself to a vehicle s travel time
  average-travel-time                    ;; average travel time calculated per day per person
  
  yesterdays-travel-time-added           ;; the average travel time added per vehicle yesterday
                                         ;; this is key in people s decision making process for whether they want
                                         ;; to go by car or bus.
  turtles-driving                        ;; number of turtles driving on any day
  median-income-drivers                  ;; the median income of turtles who drive
  median-income-bussers                  ;; the median income of turtles who take the bus
  cars                                   ;; number of cars
  busses                                 ;; number of busses
  median-income-preference-met           ;; median income for those whose transport preference was met
  median-income-preference-not-met       ;; median income for those whose transport preference was not met
  turtles-preference-met                 ;; number of people whose prefernces are met
  turtles-preference-not-met             ;; number of people whose preferences are not met
  
  color?                                 ;; color code boolean
  
  base-price-bus                         ;; base price for taking the bus
  real-price-bus                         ;; real price for taking the bus
  bus-subsidies                          ;; money going towards bus subsidies
  
  base-price-car                         ;; base price car. real price is base price plus congestion charge
  road-maintenance-expenses              ;; road maintenance expenses. The higher this is, the higher capacity on roads.
  
  base-road-capacity                     ;; 
  real-road-capacity                     ;;
  
  revenue-bus-tickets                    ;; total revenue from bus tickets
  revenue-congestion-charge              ;; total revenue from congestion charge
  
  expenses                               ;; total expenses
  budget-balance                         ;; budget balance
  
  avg-passengers-per-bus
  pollution-per-bus
  pollution-per-car
  avg-passengers-per-car
  population
]

turtles-own [
  income                                 ;; income level of turtle, 1-100
  car-love                               ;; how much the person wants to drive their car, 1-100
  willing-to-wait                        ;; how willing the person is to spend extra time on travelling by car
                                         ;; rather than travelling by public transport, 1-100
;  wishes-to-drive?                       ;; would this person ideally drive today?
;  can-afford-to-drive?                   ;; can this person afford to drive today
;  will-drive-today?                      ;; will this person actually drive today
  preference-met?                        ;; true if person travels by preferred medians
]

;;;
;;; SETUP PROCEDURES
;;;

to setup
  ;; clean up
  reset-ticks
  ;; (for this model to work with NetLogo's new plotting features,
  ;; __clear-all-and-reset-ticks should be replaced with clear-all at
  ;; the beginning of your setup procedure and reset-ticks at the end
  ;; of the procedure.)
  __clear-all-and-reset-ticks
  
  set avg-passengers-per-bus 32
  set pollution-per-bus 50
  set pollution-per-car 7
  set avg-passengers-per-car 1.5
  set population 1089
  
  set color? false
;  ask patch 0 0 [sprout 1 [set shape "house"]]
  ask patches with [distancexy -11 11 < 10] [set pcolor blue]
  



  
end



to go
  if any? turtles with [shape = "person"] [
  ;; switch over yesterdays time travel
  set yesterdays-travel-time-added travel-time-added
  ;; calculate number of cars and busses
  calc-vehicles
  ;; calculate the time delay created by number of cars
  calculate-delay-created
  ;; calculate median incomes for respectively drivers and non-drivers
  calculate-median-incomes
  ;; calculate how many turtles traveled by their preferred medians
  calculate-preference-met
  ;; calculate median income for those who traveled by preferred and those who did not.
  calculate-median-preference-met
  ask turtles with [will-drive?] [set shape "car"]
  ask turtles with [not will-drive?] [set shape "train"]
 
  calc-pollution
  ]
end

to color-code
  ifelse color? = false
  [
    set color?  true
  ]
  [
    set color?  false
  ]
end

to calc-vehicles
  set cars count turtles with [will-drive?] / avg-passengers-per-car
  set busses count turtles with [will-drive?] / avg-passengers-per-bus
end

to calculate-median-incomes
  ifelse any? turtles with [will-drive?]
  [
    set median-income-drivers median [income] of turtles with [will-drive? ]
  ]
  [
    set median-income-drivers 0
  ]  
  ifelse any? turtles with [will-drive?]
  [
    set median-income-bussers median [income] of turtles with [will-drive?]
  ]
  [
    set median-income-bussers 0
  ]
end
  
to calculate-preference-met
  set turtles-preference-met (count turtles - count turtles with [wishes-to-drive? and will-drive?])
  set turtles-preference-not-met population - turtles-preference-met
end

to calculate-median-preference-met
  ;; if clause to avoid null pointer exc
  
  ifelse any? turtles with [(wishes-to-drive? and will-drive?) or not wishes-to-drive?]
  [
     set median-income-preference-met median [income] of turtles with 
           [(wishes-to-drive? and will-drive?) or not wishes-to-drive?]
  ]
  [
    set median-income-preference-met 0
  ]
  
  ;; if clause to avoid null pointer exc
  ifelse any? turtles with [wishes-to-drive? and not will-drive?]
  [
     set median-income-preference-not-met median [income] of turtles with [wishes-to-drive? and not will-drive?]
  ]
  [
    set median-income-preference-not-met 0
  ]


end  
  
to color-turtle
  ask turtles[
  ;; coloring people per income
  ;; dark red for lowest quartile, pink for next, light blue for next, dark blue for highest quartile
  if income <= 25
  [
    set color 15
  ]
  if income > 25 and income <= 50
  [
    set color 17
  ]
  if income > 50 and income <= 75
  [
    set color 95
  ]
  if income > 75
  [
    set color 105
  ]
  ]
end

to white-turtle
  ask turtles
  [
    set color white
  ]
  
end

to calc-pollution
  ;; calculates pollution by multiplying pollution per car with no of cars and ditto for busses
  set global-pollution-per-day cars * pollution-per-car + busses * pollution-per-bus
  end

to calculate-delay-created
  ;; calculates delay created by finding sum of vehicles. All vehicles cause same amount of delay which probably isnt true...
  set travel-time-added cars + busses
  
end

to-report wishes-to-drive? ;; this determines if the turtle would ideally drive
  report car-love - (yesterdays-travel-time-added / (willing-to-wait + 0.01 )) > 0
end

to-report can-afford-to-drive? ;; this determines if the turtle can afford to drive. This needs to be tweaked to take into
                       ;; consideration feedback effect from congestion charge lowering price of public transp
                       report 1
;  report congestion-charge-cost / 2 < income
end

to-report will-drive? ;; this determines if the turle will actually drive
  report wishes-to-drive? and can-afford-to-drive?
end

to add-person
    ;; create population
  create-turtles 1
  [
    ;; setting shape person
    set shape "house"
    ;; placing randomly on map in unoccupied location
    move-to min-one-of patches with [not any? turtles-here and pcolor != blue] [distancexy -4 3]
;    move-to min-one-of patches with [not any? turtles-here] [sum (list abs pxcor abs pycor)]
    ;;move-to first patches with  [any? turtles-here = false]
    

    
    ;; setting income randomly (will be changed as part of gini coefficient implementation)
    set income random 99
    set color white
    set car-love random 99
    set willing-to-wait random 99

    ;; adding 1 to all turtle properties to avoid divide by zero errors. Look up how to set a range for random and correct this. 
    set income income + 1
    set car-love car-love + 1
    set willing-to-wait willing-to-wait + 1
  ]
end

to remove-person
  ask max-one-of patches with [any? turtles-here] [sum (list abs pxcor abs pycor)] [ask turtles-here [die]]
end
@#$#@#$#@
GRAPHICS-WINDOW
5
10
250
271
11
11
10.0
1
10
1
1
1
0
0
0
1
-11
11
-11
11
0
0
1
ticks
30.0

@#$#@#$#@
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

bus
false
0
Polygon -7500403 true true 15 206 15 150 15 120 30 105 270 105 285 120 285 135 285 206 270 210 30 210
Rectangle -16777216 true false 36 126 231 159
Line -7500403 false 60 135 60 165
Line -7500403 false 60 120 60 165
Line -7500403 false 90 120 90 165
Line -7500403 false 120 120 120 165
Line -7500403 false 150 120 150 165
Line -7500403 false 180 120 180 165
Line -7500403 false 210 120 210 165
Line -7500403 false 240 135 240 165
Rectangle -16777216 true false 15 174 285 182
Circle -16777216 true false 48 187 42
Rectangle -16777216 true false 240 127 276 205
Circle -16777216 true false 195 187 42
Line -7500403 false 257 120 257 207

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
0
Rectangle -7500403 true true 151 225 180 285
Rectangle -7500403 true true 47 225 75 285
Rectangle -7500403 true true 15 75 210 225
Circle -7500403 true true 135 75 150
Circle -16777216 true false 165 76 116

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

train
false
0
Rectangle -7500403 true true 30 105 240 150
Polygon -7500403 true true 240 105 270 30 180 30 210 105
Polygon -7500403 true true 195 180 270 180 300 210 195 210
Circle -7500403 true true 0 165 90
Circle -7500403 true true 240 225 30
Circle -7500403 true true 90 165 90
Circle -7500403 true true 195 225 30
Rectangle -7500403 true true 0 30 105 150
Rectangle -16777216 true false 30 60 75 105
Polygon -7500403 true true 195 180 165 150 240 150 240 180
Rectangle -7500403 true true 135 75 165 105
Rectangle -7500403 true true 225 120 255 150
Rectangle -16777216 true false 30 203 150 218

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

x
false
0
Polygon -7500403 true true 270 75 225 30 30 225 75 270
Polygon -7500403 true true 30 75 75 30 270 225 225 270

@#$#@#$#@
NetLogo 5.2.0
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
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
