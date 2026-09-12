;;; welcome-themes.el --- Animated anime welcome themes -*- lexical-binding: t; -*-
(require 'svg)
(load (expand-file-name "welcome-geometry.el"
                        (file-name-directory (or load-file-name buffer-file-name)))
      nil 'nomessage)

(defconst my/welcome-themes
  '((pokemon :name "POKEMON" :background "#111b30" :accent "#ffd75e"
             :art my/pokemon-art
             :subtitle "Ready for your next adventure?"
             :footer "One small step. One new discovery."
             :greetings ["Welcome back, Trainer! A new adventure awaits."
                         "Pikachu is ready. Let's level up today!"
                         "A new route, a fresh start. Welcome home!"]
             :farewells ["See you next time, Trainer!"
                         "Pikachu will be waiting. Rest up!"
                         "Adventure paused. Keep exploring!"])
    (beyblade :name "BEYBLADE" :background "#101c2c" :accent "#66dcff"
              :art my/beyblade-art
              :subtitle "Three. Two. One. Let it rip!"
              :footer "Find your balance. Build your momentum."
              :greetings ["Welcome to the stadium, Blader!"
                          "Your next challenge is waiting. Let it rip!"
                          "New session. Fresh spin. Welcome back!"]
              :farewells ["Stadium lights out. See you next round!"
                          "Keep your spirit spinning, Blader!"
                          "A champion needs rest. Until next time!"])
    (bakugan :name "BAKUGAN" :background "#251421" :accent "#ff9566"
             :art my/bakugan-art
             :subtitle "Gate Card, set! Bakugan, stand!"
             :footer "Small beginnings. Extraordinary power."
             :greetings ["Welcome back, Brawler! Your arena awaits."
                         "Gate Card, set! Ready for a new challenge?"
                         "Time to unleash your potential, Brawler!"]
             :farewells ["Battle complete. See you next time, Brawler!"
                         "Return to ball form. Recharge for tomorrow!"
                         "The arena will be waiting. Stay bold!"])))

(defvar my/welcome-theme 'pokemon)
(defun my/welcome-theme-value (property)
  (plist-get (cdr (assq my/welcome-theme my/welcome-themes)) property))

(provide 'welcome-themes)
