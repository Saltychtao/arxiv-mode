;; arXiv query functions

(require 'xml)

;; URL of the arXiv api
;; check https://arxiv.org/help/api/user-manual for information
(setq arxiv-url "http://export.arxiv.org/api/query")
(setq arxiv-query-total-results nil)

(defun arxiv-extract-pdf (my-list)
  "Function for extracting the url for pdf file recursively"
  (if my-list
      (let* ((sub-list (car (cdr (car my-list))))
             (sub-title (cdr (assoc 'title sub-list))))
        ;; (message "%S\n :%S" sub-list sub-title)
        (if (and sub-title (equal sub-title "pdf"))
            (progn 
              ;; (message sub-title)
              (cdr (assoc 'href sub-list)))
          (arxiv-extract-pdf (cdr my-list))))))

(defun arxiv-geturl-date (dateStart dateEnd category &optional start max-num)
  "get the API url for articles between dateStart and dateEnd in the specified category."
  (unless start
    (setq start 0))  ; Start with the first result
  (unless max-num
    (setq max-num 100))  ; Default to 100 results per page
  (format "%s?search_query=submittedDate:[%s0000+TO+%s0000]+AND+cat:%s*&sortBy=submittedDate&sortOrder=descending&start=%d&max_results=%d" 
          arxiv-url dateStart dateEnd category start max-num))

(defun arxiv-geturl-author (author &optional category start max-num)
  "get the API url for articles by certain author."
  (unless start
    (setq start 0))  ; Start with the first result
  (unless max-num
    (setq max-num 100))  ; Default to 100 results per page
  (setq author (replace-regexp-in-string " " "+" author))
  (setq author (replace-regexp-in-string "\"" "%22" author))
  (if category
      (format "%s?search_query=au:%s+AND+cat:%s*&start=%d&max_results=%d"
	      arxiv-url author category start max-num)
    (format "%s?search_query=au:%s&start=%d&max_results=%d"
	      arxiv-url author start max-num)))  

(defun arxiv-parse-api (url)
  "Call arXiv api url and parse its response.
Return a alist with various fields."
  (let ((my-list) (my-buffer)))
  (setq my-list nil)
  (setq my-buffer (url-retrieve-synchronously url))
  ;; (message "%s" my-buffer)
  (set-buffer my-buffer)
  (goto-char (point-min))
  ;; (message "%d" (point-max))
  (setq my-point (search-forward "<?xml"))
  (goto-char (- my-point 5))
  (setq root (libxml-parse-xml-region (point) (point-max)))
  (setq arxiv-query-total-results (string-to-int (nth 2 (car (xml-get-children root 'totalResults)))))
  (message "%S" arxiv-query-total-results)
  (setq entries (xml-get-children root 'entry))
  ;; (message "%d" (safe-length entries))
  ;; (message "%s" (nth 0 entries))
  (mapcar 
   (lambda (entry) 
     (progn
       ;; (message "a" )
       ;; (message "%s" entry)
       (setq paper (xml-node-children entry))
       ;; (message "%S" (xml-get-children paper 'link))
       ;; (message "%S" (arxiv-extract-pdf (xml-get-children paper 'link)))
       (setq my-pdf (arxiv-extract-pdf (xml-get-children paper 'link)))
       ;; (message "%S" (cdr (assoc 'id paper)))
       ;; (message "%S" (car (xml-node-children (car paper))))
       (setq my-url (nth 1 (cdr (assoc 'id paper))))
       ;; (message "%S" my-url)
       (setq my-title (car (last (xml-node-children (car (xml-get-children paper 'title))))))
       ;; (message title)
       (setq my-title (replace-regexp-in-string "[ \n]+" " " my-title))
       (setq my-abstract (car (xml-node-children (car (xml-get-children paper 'summary)))))
       (setq my-publishdate (car (xml-node-children (car (xml-get-children paper 'published)))))
       (setq my-publishdate (replace-regexp-in-string "[TZ]" " " my-publishdate))
       (setq my-authors (xml-get-children paper 'author))
       (setq my-names (mapcar 
		       (lambda (author) (car (last (car (xml-get-children author 'name)))))
		       my-authors))
       (setq alist-entry `((title . ,my-title)
			   (authors . ,my-names)
			   (abstract . ,my-abstract)
			   (url . ,my-url)
			   (date . ,my-publishdate)
			   (pdf . ,my-pdf)))
       (setq my-list (append my-list `(,alist-entry)))
       ;; (message "%S\n" alist-entry)
       ;; )) entries)
       )) entries)
  my-list)
;; (message "\n Title: %s\n Authors: %S\n URL: %s\n Abstract: %S \n"
;;          title names url abstract)

(defun arxiv-query (cat date-start date-end &optional max-num)
  "Query arXiv for articles in a given category submitted between date-start and date-end."
  (unless (> (string-to-number date-end) (string-to-number date-start))
    (user-error "incorrect date specification"))  
  (arxiv-parse-api (arxiv-geturl-date date-start date-end cat)))

(defun arxiv-query-author (author &optional cat max-num)
  "Query arXiv for articles by certain authors (in a given category)."
  (arxiv-parse-api (arxiv-geturl-author author cat)))
  
(provide 'arxiv-query)
;;; arxiv-query.el ends hereG
