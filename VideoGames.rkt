#lang racket

(require csv-reading) ; CSV reading
(require racket/string) ; String maniuplation 

; Case-insensitive string contains check.
(define (string-contains-ci? str1 str2)
  (string-contains? (string-downcase str1) (string-downcase str2)))

; Reads a CSV file and returns a list of hash tables.
(define (read-csv-to-games filepath)
  (call-with-input-file filepath
    (lambda (input-port)
      (let* ([rows (csv->list input-port)] ; Read CSV data from the input port.
             [headers (map (lambda (sym) (if (symbol? sym) (symbol->string sym) sym)) (car rows))] ; Read the first row in as headers
             [data (map (lambda (row) (row->hash row headers)) (cdr rows))] ; Skip the headers row and begin to read the rest of the rows.
             )
        data))
    #:mode 'text)) ; Ensure the file is read in text mode.

; Converts a row to a hash table using provided headers.
(define (row->hash row headers)
  (for/fold ([h (hash)]) ([key (in-list headers)] [value (in-list row)])
    (hash-set h key (if (string-numeric? value) (string->number value) value))))

; Detects if a string represents a numeric value.
(define (string-numeric? str)
  (regexp-match? #rx"^-?[0-9]+(\\.[0-9]+)?$" str))

; Custom prompt function for user input
(define (prompt-for prompt)
  (display prompt)
  (let ([input (read-line)])
    (if (string=? input "skip") "" input)))

; Prompts the user for input and collects filtering options.
(define (collect-input)
  (let ([options (make-hash)])
    (define promptsA
      '(("Game Title" "Enter the Game Title (or type 'next' to proceed): ")
        ("Start Year" "Enter the Start Year (or type 'next' to proceed): ")
        ("End Year" "Enter the End Year (or type 'next' to proceed): ")
        ("Region" "Enter the Region [North America, Europe, Japan, Rest of World, or Global] (or type 'next' to proceed): ")
        ("Genre" "Enter the Genre (or type 'next' to proceed): ")
        ("Publisher" "Enter the Publisher (or type 'next' to proceed): ")))
    
    (for ([prompt prompts])
      (let* ([key (first prompt)]
             [message (second prompt)]
             [input (prompt-for message)])
        (unless (string-ci=? input "next")
          (hash-set! options key input))))
    options))

; Convert strings to numbers to prevent contract violation
(define (safe-string->number s default)
  (if (string? s)
      (let ([num (string->number s)])
        (if num num default)) ; Convert to number if possible, otherwise use default.
      default)) ; Use default if input is not a string.

; Updated apply-filters function with corrected logic
(define (apply-filters game options)
  (let* ((game-year (hash-ref game "Year" 0))
         (start-year (safe-string->number (hash-ref options "Start Year" "") 1950))
         (end-year (safe-string->number (hash-ref options "End Year" "") 2024))
         (region (hash-ref options "Region" #f))
         (game-title (hash-ref options "Game Title" ""))
         (genre (hash-ref options "Genre" #f))
         (publisher (hash-ref options "Publisher" #f))
         ; Combine both start and end year for a single option to filter by
         (year-input-provided (and (hash-has-key? options "Start Year") (hash-has-key? options "End Year"))))
    (let ((region-sales
           (cond [(or (not region) (string=? region "next")) 0]
                 [(string=? region "Global") (hash-ref game "Global" 0)]
                 [(string=? region "North America") (hash-ref game "North America" 0)]
                 [(string=? region "Europe") (hash-ref game "Europe" 0)]
                 [(string=? region "Japan") (hash-ref game "Japan" 0)]
                 [(string=? region "Rest of World") (hash-ref game "Rest of World" 0)]
                 [else 0])))
      (and
       (or (string=? game-title "") (string-contains-ci? (hash-ref game "Game Title" "") game-title))
       (or (not year-input-provided) (and (<= start-year game-year) (>= end-year game-year)))
       (or (not region) (> region-sales 0))
       (or (not genre) (string-contains-ci? (hash-ref game "Genre" "") genre))
       (or (not publisher) (string-contains-ci? (hash-ref game "Publisher" "") publisher))))))

; Display a row related to a game that matches query.
(define (display-game game)
  (for ([field (hash->list game)]) ; Iterate over games
    (printf "~a: ~a, " (car field) (cdr field))) ; Display column name and value present
  (newline))

; Sorts and displays filtered games based on matching the users query.
(define (sort-and-display-games games sort-options)
  (let ([sorted-games
         (cond [(string-ci=? sort-options "Rank") (sort games (lambda (a b) (< (hash-ref a "Rank") (hash-ref b "Rank"))))]
               [(string-ci=? sort-options "Review") (sort games (lambda (a b) (< (hash-ref a "Review") (hash-ref b "Review"))))]
               [else games])])
    (for-each
     (lambda (game)
       (display-game game))
     sorted-games)))

; Main
(define (main)
  (display "Welcome to the game database!\n")
  (define filepath "Video Games Sales.csv") ; Path to the CSV file containing game data
  (define games (read-csv-to-games filepath)) ; Read game data from CSV file
  (let loop ([count 0])
    (when (< count 3)
      (let* ([options (collect-input)] ; Collect filtering options from the user
             [filtered-games (filter (lambda (game) (apply-filters game options)) games)]) ; Apply filters to games
        (if (not (empty? filtered-games))
            ; Display filtered games if any are found
            (begin
              ; (display "Filtered games:\n")    Debugging statement
              (let ([sort-options (prompt-for "Sort results by 'Rank' (Sales) or 'Review'? (type 'Rank' or 'Review'): ")])
                (sort-and-display-games filtered-games sort-options)))
            ; Notify the user if no games match the filters
            (display "No games found matching the specified criteria.\n")))
      (set! count (+ count 1))
      (display "Would you like to filter again? (yes/no): ")
      (let ([choice (string-downcase (read-line))])
        (cond
          [(string=? choice "yes") (loop count)] ; If the user wants to filter again, loop back
          [(string=? choice "no") (display "Goodbye!")])))))

(main)