;;; welcome-geometry.el --- Procedural, shaded SVG animation -*- lexical-binding: t; -*-
;; All scenes are paths, projected polygons and gradients. No raster assets,
;; embedded images, network requests, external renderers or texture files.
(require 'svg)
(require 'cl-lib)

(defconst my/welcome-frame-count 24)

(defun my/scene-gradient (defs id colors &optional radial)
  (let ((node (if radial
                  (svg-node defs 'radialGradient :id id :cx "32%" :cy "22%" :r "80%")
                (svg-node defs 'linearGradient :id id :x1 "0%" :y1 "0%" :x2 "80%" :y2 "100%"))))
    (cl-loop for color in colors for index from 0 do
             (svg-node node 'stop :offset (format "%d%%" (/ (* index 100) (1- (length colors))))
                       :stop-color color))))

(defun my/scene-path (node path fill &optional stroke thickness)
  (svg-node node 'path :d path :fill fill :stroke (or stroke "none")
            :stroke-width (or thickness 1) :stroke-linejoin "round" :stroke-linecap "round"))

(defun my/scene-base (width background accent)
  (let* ((svg (svg-create width (round (* width 0.43)) :viewBox "0 0 800 344"))
         (defs (svg-node svg 'defs)))
    (my/scene-gradient defs "sky" (list background "#080d18") t)
    (my/scene-gradient defs "gold" '("#fff6b4" "#ffdf5a" "#dea128" "#7f4814") t)
    (my/scene-gradient defs "metal" '("#f1f7ff" "#8199b4" "#e9f4ff" "#364861"))
    (my/scene-gradient defs "blue" '("#b2f5ff" "#29a6ec" "#164d96" "#0b203c") t)
    (my/scene-gradient defs "red" '("#ffb999" "#f15a48" "#a52237" "#450f28") t)
    (my/scene-gradient defs "ivory" '("#ffffff" "#dee9f3" "#7b8a9e") t)
    (my/scene-gradient defs "eye" '("#6c5447" "#211e27" "#060910") t)
    (svg-rectangle svg 0 0 800 344 :rx 22 :fill "url(#sky)")
    (svg-ellipse svg 400 295 245 36 :fill background :stroke accent :stroke-opacity 0.1)
    (svg-line svg 75 314 725 314 :stroke accent :stroke-opacity 0.16)
    svg))

(defun my/scene-particles (svg step accent)
  (dotimes (n 12)
    (let ((x (+ 65 (% (+ (* n 97) (* step 3)) 670)))
          (y (+ 33 (% (+ (* n 43) (- 80 (* step 2))) 215))))
      (svg-circle svg x y (if (= (% n 3) 0) 2 1) :fill accent
                  :fill-opacity (+ 0.15 (* 0.07 (% (+ n step) 6)))))))

(defun my/pokemon-art (step width)
  "Render a shaded Pikachu with breathing, ear motion, blinking and sparks."
  (let* ((svg (my/scene-base width "#18243a" "#ffd75e"))
         (phase (* 2 float-pi (/ step (float my/welcome-frame-count))))
         (lift (* 3 (sin phase)))
         body)
    (my/scene-particles svg step "#ffe59b")
    (svg-ellipse svg 412 287 98 14 :fill "#040914" :fill-opacity 0.75)
    (setq body (svg-node svg 'g :transform (format "translate(0 %.2f)" lift)))
    ;; Lightning tail, with an offset edge giving it actual thickness.
    (my/scene-path body "M458 235 L500 197 L479 183 L537 128 L558 153 L519 186 L541 202 L480 253 Z"
                   "#91601c" "#643c18" 2)
    (my/scene-path body "M452 229 L494 191 L473 177 L531 122 L552 147 L513 180 L535 196 L474 247 Z"
                   "url(#gold)" "#bb8422" 1.5)
    (my/scene-path body "M452 229 L474 210 L489 224 L474 247 Z" "#855326")
    (my/scene-path body "M489 174 L531 130 L545 146" "none" "#fff2a0" 2)
    ;; Sculpted torso, haunches and feet.
    (my/scene-path body "M360 170 C325 200 325 258 353 278 C380 297 447 288 467 266 C484 238 465 194 442 173 Z"
                   "url(#gold)" "#a97b27" 1.5)
    (my/scene-path body "M371 211 C357 244 372 273 405 277 C436 273 448 247 438 217 C411 230 389 229 371 211"
                   "#ffe386" nil)
    (my/scene-path body "M355 265 C330 267 320 282 343 287 L377 285 C389 276 374 264 355 265"
                   "url(#gold)" "#a97b27" 1)
    (my/scene-path body "M444 265 C467 265 490 279 471 286 L436 287 C419 278 430 265 444 265"
                   "url(#gold)" "#a97b27" 1)
    (dolist (x '(344 352 451 459))
      (svg-line body x 278 (+ x 2) 284 :stroke "#bc8a31" :stroke-width 1.2))
    ;; Ears use curved paths rather than triangles. Black tips share the contour.
    (let ((ear (svg-node body 'g :transform (format "rotate(%.2f 363 130)" (* 3 (sin phase))))))
      (my/scene-path ear "M347 140 C326 110 301 55 316 28 C342 42 364 96 373 135 Z"
                     "url(#gold)" "#ae7c28" 1.5)
      (my/scene-path ear "M316 28 C326 32 337 46 344 62 L326 76 C315 54 311 40 316 28" "#222839")
      (my/scene-path ear "M335 78 Q351 106 357 124" "none" "#fff3a2" 3))
    (let ((ear (svg-node body 'g :transform (format "rotate(%.2f 444 127)" (* -4 (sin phase))))))
      (my/scene-path ear "M428 133 C445 96 466 50 494 41 C500 65 470 117 456 143 Z"
                     "url(#gold)" "#ae7c28" 1.5)
      (my/scene-path ear "M473 54 Q485 43 494 41 Q499 54 485 81 L467 72 Z" "#222839"))
    ;; Cheek silhouette and forehead are a continuous shaded surface.
    (my/scene-path body "M350 130 C364 104 431 99 450 128 C464 144 458 151 470 167 C482 187 459 208 441 214 C407 229 364 216 347 201 C326 187 334 168 341 156 Z"
                   "url(#gold)" "#b98628" 1.5)
    (my/scene-path body "M361 132 C380 113 421 112 439 129" "none" "#fff0a0" 3)
    (dolist (x '(373 429))
      (if (memq step '(18 19))
          (my/scene-path body (format "M%d 161 q9 8 18 -1" (- x 9)) "none" "#292432" 3)
        (svg-ellipse body x 159 10 13 :fill "url(#eye)")
        (svg-ellipse body (- x 3) 155 3.6 4.8 :fill "#ffffff")
        (svg-circle body (+ x 3) 166 1.5 :fill "#d5bea4")))
    (svg-ellipse body 348 183 14 11 :fill "url(#red)")
    (svg-ellipse body 456 183 14 11 :fill "url(#red)")
    (my/scene-path body "M397 173 Q402 170 407 173 L402 177 Z" "#342c2c")
    (my/scene-path body "M387 185 Q396 192 402 185 Q409 192 417 184" "none" "#603b2e" 2)
    ;; Small paws and fur contours.
    (my/scene-path body "M351 215 Q334 239 352 248 Q367 246 370 221" "url(#gold)" "#bb862a" 1.2)
    (my/scene-path body "M447 218 Q466 238 448 248 Q433 246 434 223" "url(#gold)" "#bb862a" 1.2)
    (dotimes (n 16)
      (let ((x (+ 365 (* (% n 8) 10))) (y (+ 202 (* (/ n 8) 5))))
        (my/scene-path body (format "M%d %d q2 4 4 0" x y) "none" "#fff0a0" 0.7)))
    ;; Reflective Poke Ball, built entirely from curved surfaces.
    (svg-circle svg 230 265 29 :fill "url(#ivory)" :stroke "#141d2b" :stroke-width 2)
    (my/scene-path svg "M201 263 A29 29 0 0 1 259 263 Q230 275 201 263 Z" "url(#red)")
    (my/scene-path svg "M201 263 Q230 275 259 263" "none" "#172030" 5)
    (svg-circle svg 230 270 9 :fill "#172030")
    (svg-circle svg 230 270 5.5 :fill "url(#ivory)")
    (my/scene-path svg "M213 250 Q223 239 237 243" "none" "#ffd6bd" 2)
    (when (< (% step 8) 3)
      (my/scene-path svg "M301 166 L287 151 L294 173 L275 169 L288 190" "none" "#ffe474" 2)
      (my/scene-path svg "M497 174 L513 160 L508 179 L527 176 L518 194" "none" "#ffe474" 2))
    (svg-image svg :ascent 'center)))

(defun my/bey-project (radius angle z)
  "Project a rotating 3D ring onto the stadium's tilted viewing plane."
  (cons (+ 401 (* radius (cos angle)))
        (+ 235 (* 0.43 radius (sin angle)) (* -0.95 z))))

(defun my/bey-ring (svg radius z depth phase teeth)
  "Render a thick faceted ring with stationary directional lighting."
  (let* ((count 60)
         (vertices (cl-loop for i below count
                            for a = (+ phase (* i (/ (* 2 float-pi) count)))
                            for r = (+ radius (if teeth (* 10 (cos (* 6 (- a phase)))) 0))
                            collect (list a r)))
         faces)
    (dotimes (i count)
      (let* ((a (nth i vertices)) (b (nth (% (1+ i) count) vertices))
             (angle (/ (+ (car a) (car b)) 2)))
        (push (list (sin (car a))
                    (list (my/bey-project (cadr a) (car a) z)
                          (my/bey-project (cadr b) (car b) z)
                          (my/bey-project (cadr b) (car b) (- z depth))
                          (my/bey-project (cadr a) (car a) (- z depth)))
                    (format "#%02x%02x%02x"
                            (round (+ 65 (* 75 (+ 1 (cos (+ angle 2))))))
                            (round (+ 80 (* 70 (+ 1 (cos (+ angle 2))))))
                            (round (+ 105 (* 65 (+ 1 (cos (+ angle 2)))))))) faces)))
    (dolist (face (sort faces (lambda (a b) (< (car a) (car b)))))
      (svg-polygon svg (nth 1 face) :fill (nth 2 face) :stroke (nth 2 face) :stroke-width 0.6))
    (svg-polygon svg (mapcar (lambda (v) (my/bey-project (cadr v) (car v) z)) vertices)
                 :fill "url(#metal)" :stroke "#d8e5f0" :stroke-width 1)))

(defun my/beyblade-art (step width)
  "Render a visibly layered spinning battle top using projected 3D geometry."
  (let* ((svg (my/scene-base width "#10243b" "#66dcff"))
         (phase (* 2 float-pi (/ step (float my/welcome-frame-count)))))
    ;; Stadium perspective, rings and abrasion marks.
    (dolist (r '(170 230 295 355))
      (svg-ellipse svg 400 230 r (* r 0.28) :fill "none" :stroke "#315978"
                   :stroke-width (if (= r 355) 4 1.2) :stroke-opacity 0.6))
    (dotimes (n 20)
      (let ((x (+ 160 (* n 25))))
        (svg-line svg x 282 (+ x 17) 279 :stroke "#5b7a95" :stroke-opacity 0.2)))
    (svg-ellipse svg 401 252 111 14 :fill "#040a16" :fill-opacity 0.85)
    ;; Performance tip and spin track are visible beneath the fusion wheel.
    (my/scene-path svg "M378 224 L425 224 L411 249 Q402 259 395 249 Z" "url(#red)" "#182838" 2)
    (svg-ellipse svg 401 221 34 11 :fill "url(#blue)" :stroke "#62d5ff" :stroke-width 2)
    (my/scene-path svg "M367 207 L435 207 L432 226 Q401 240 370 226 Z" "url(#blue)")
    (my/bey-ring svg 73 42 13 phase nil)
    (my/bey-ring svg 119 74 17 phase t)
    ;; Six sculpted attack blades; each rotates independently of the light.
    (dotimes (blade 6)
      (let* ((a (+ phase (* blade (/ float-pi 3))))
             (coords '((62 . -0.12) (112 . -0.17) (140 . 0.03) (124 . 0.25)
                       (93 . 0.38) (83 . 0.18) (57 . 0.15))))
        (svg-polygon svg
                     (mapcar (lambda (p) (my/bey-project (car p) (+ a (cdr p)) 80)) coords)
                     :fill (if (= (% blade 2) 0) "url(#blue)" "url(#metal)")
                     :stroke "#90daf2" :stroke-width 1.5)
        (svg-polyline svg (mapcar (lambda (p) (my/bey-project (car p) (+ a (cdr p)) 81))
                                  '((75 . -0.07) (111 . -0.09) (126 . 0.03)))
                      :fill "none" :stroke "#d9f9ff" :stroke-width 2 :stroke-opacity 0.8)))
    (svg-ellipse svg 401 (- 235 (* 0.95 82)) 62 27 :fill "url(#blue)" :stroke "#213958" :stroke-width 3)
    (svg-ellipse svg 401 (- 235 (* 0.95 84)) 43 19 :fill "#0b254d" :stroke "#9bdef4" :stroke-width 2)
    (svg-polygon svg (cl-loop for n below 6 collect
                             (my/bey-project 34 (+ phase (* n (/ float-pi 3))) 87))
                 :fill "url(#red)" :stroke "#ffc69b" :stroke-width 1.5)
    ;; White wing insignia on the face bolt emphasizes actual rotation.
    (let ((badge (svg-node svg 'g :transform
                           (format "translate(401 152.35) scale(1 .43) rotate(%.2f)" (* step 15)))))
      (my/scene-path badge "M-18 3 L-9 -14 L-4 -4 L14 -17 L8 -3 L21 -8 L9 7 L-4 10 L-11 19 L-9 7 Z"
                     "#eefaff"))
    ;; Curved streaks follow the stadium plane, rather than rotating the scene.
    (my/scene-path svg "M210 188 C145 230 255 286 451 272" "none" "#47c9ff" 2)
    (my/scene-path svg "M556 158 C669 185 638 252 547 262" "none" "#7deaff" 2)
    (dotimes (n 7)
      (let* ((a (+ phase (* n 0.87))) (p (my/bey-project 168 a 20)))
        (svg-line svg (car p) (cdr p) (+ (car p) 12) (- (cdr p) 5)
                  :stroke "#c9f7ff" :stroke-width 1.5 :stroke-opacity 0.7)))
    (svg-image svg :ascent 'center)))

(defun my/bakugan-art (step width)
  "Render a horned, plated Dragonoid with articulated wings and shell panels."
  (let* ((svg (my/scene-base width "#2b182a" "#ff9566"))
         (phase (* 2 float-pi (/ step (float my/welcome-frame-count))))
         (flap (* 9 (sin phase)))
         dragon)
    (my/scene-particles svg step "#ffad65")
    (svg-polygon svg '((241 . 253) (446 . 214) (587 . 285) (367 . 325))
                 :fill "#352333" :stroke "#e7a35d" :stroke-width 2)
    (svg-polygon svg '((259 . 253) (444 . 225) (562 . 282) (369 . 313))
                 :fill "none" :stroke "#af6743" :stroke-width 1)
    (svg-ellipse svg 406 276 90 18 :fill "#0d0c19" :fill-opacity 0.8)
    (setq dragon (svg-node svg 'g :transform (format "translate(0 %.2f)" (* 2 (sin phase)))))
    ;; Wings are curved membranes supported by gold-edged mechanical spars.
    (dolist (side '(-1 1))
      (let ((wing (svg-node dragon 'g :transform
                            (format "translate(404 187) scale(%d 1) rotate(%.2f)" side flap))))
        (my/scene-path wing "M24 6 C55 -34 67 -105 146 -140 L132 -74 L174 -40 L124 -32 L137 14 L82 -2 L58 39 Z"
                       "url(#red)" "#ecac6c" 2)
        (my/scene-path wing "M40 0 Q81 -56 138 -125 L115 -68 L152 -42 L109 -36 L122 -3 L82 -15 L58 18 Z"
                       "#72213c")
        (my/scene-path wing "M36 3 Q82 -42 142 -132 M81 -42 L160 -41 M81 -42 L129 9"
                       "none" "#ffbe75" 3)
        (my/scene-path wing "M22 7 L42 -7 L62 24 L49 42 Z" "url(#metal)" "#733548" 2)
        (svg-circle wing 43 17 7 :fill "#5b2235" :stroke "#efb76e" :stroke-width 3)))
    ;; Tail sits behind the spherical core, exposing curved shell construction.
    (my/scene-path dragon "M434 246 Q514 267 535 216 L541 201 L546 224 Q546 274 459 276 Z"
                   "url(#red)" "#f79a60" 1.5)
    (svg-ellipse dragon 404 215 53 57 :fill "url(#red)" :stroke "#bc5b47" :stroke-width 2)
    (my/scene-path dragon "M356 198 Q376 174 379 164 M449 197 Q430 173 430 162"
                   "none" "#ffbe75" 4)
    (my/scene-path dragon "M377 200 L404 186 L431 201 L424 246 L405 267 L383 247 Z"
                   "url(#gold)" "#642a31" 2)
    (dotimes (n 4)
      (my/scene-path dragon (format "M%d %d Q405 %d %d %d" (+ 382 n) (+ 212 (* n 10))
                                    (+ 224 (* n 10)) (- 427 n) (+ 212 (* n 10)))
                     "none" "#aa6538" 2))
    ;; Head, brows, crest, eyes and a short snout instead of a generic sphere.
    (my/scene-path dragon "M374 181 L363 150 L376 114 L404 95 L433 116 L445 150 L432 181 L404 194 Z"
                   "url(#red)" "#f69c66" 2)
    (my/scene-path dragon "M388 112 L402 65 L414 110 L405 129 Z" "url(#gold)" "#b17640" 1.5)
    (my/scene-path dragon "M375 134 L353 94 L374 109 L389 129 M430 132 L452 94 L432 108 L419 128"
                   "url(#gold)" "#aa683d" 1)
    (my/scene-path dragon "M374 145 L393 150 L385 161 L372 156 Z" "#192831")
    (my/scene-path dragon "M434 145 L415 150 L423 161 L436 156 Z" "#192831")
    (my/scene-path dragon "M377 150 L389 152 L382 157 Z M431 150 L419 152 L426 157 Z" "#9bffd7")
    (my/scene-path dragon "M394 158 L413 158 L422 175 L406 184 L389 175 Z" "url(#red)" "#ee956b" 1)
    (my/scene-path dragon "M393 176 L417 176 L407 188 Z" "#36182b")
    (my/scene-path dragon "M394 176 L397 181 L400 176 M411 176 L414 181 L417 176" "#ffeec6")
    ;; Jointed legs and three ivory claws per foot.
    (dolist (side '(-1 1))
      (let ((leg (svg-node dragon 'g :transform (format "translate(404 234) scale(%d 1)" side))))
        (my/scene-path leg "M26 0 L49 10 L42 29 L60 39 L54 47 L18 41 L16 25 Z"
                       "url(#red)" "#ce7651" 2)
        (svg-circle leg 34 18 6 :fill "url(#metal)" :stroke "#572a3b" :stroke-width 2)
        (dotimes (n 3)
          (my/scene-path leg (format "M%d 38 l7 10 l-11 -2 Z" (+ 27 (* n 10))) "url(#ivory)"))))
    ;; A closed ball alongside the unfolded figure makes the Bakugan identity clear.
    (svg-circle svg 602 267 30 :fill "url(#red)" :stroke "#ec9864" :stroke-width 1.5)
    (my/scene-path svg "M580 247 Q613 257 616 292 M576 280 Q599 267 630 267 M602 237 L596 253 L608 270"
                   "none" "#4f2333" 3)
    (my/scene-path svg "M591 241 Q606 237 618 250" "none" "#ffd29b" 2)
    (svg-image svg :ascent 'center)))

(provide 'welcome-geometry)
