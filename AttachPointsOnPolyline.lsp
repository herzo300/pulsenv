;;; ==========================================================================
;;; AutoLISP утилита: ATTACHPTS / AP (ВСТАВКА ВЕРШИН ПРИМЫКАНИЯ ЧЕРЕЗ PL-VxAdd)
;;; ==========================================================================
;;; Назначение:
;;;   Пользователь в 1 клик выбирает полилинию. Утилита автоматически 
;;;   сканирует все блоки на чертеже и вставляет вершины примыкания 
;;;   НЕПОСРЕДСТВЕННО В САМУ ПОЛИЛИНИЮ с помощью PL-VxAdd.
;;; 
;;;   • БЕЗ создания объектов POINT
;;;   • БЕЗ создания новых/лишних слоев
;;; 
;;; Вызов в AutoCAD: AP или ATTACHPTS
;;; ==========================================================================

(vl-load-com)

;; Функция вызова / вставки вершины примыкания в полилинию
(defun _AddVertexToPolyline (poly-ent pt / doc obj param segment-idx 2d-pt)
  (cond
    ;; 1. Если функция PL-VxAdd определена как LISP-функция
    ((eval 'PL-VxAdd)
     (vl-catch-all-apply 'PL-VxAdd (list poly-ent pt)))
    
    ;; 2. Если PL-VxAdd зарегистрирована как команда AutoCAD
    ((where-is-command "PL-VxAdd")
     (vl-cmdf "_.PL-VxAdd" poly-ent pt))
     
    ;; 3. Автоматический фоллбек: прямое добавление вершины в полилинию через ActiveX
    (t
     (progn
       (setq obj (vlax-ename->vla-object poly-ent))
       (setq param (vlax-curve-getParamAtPoint obj pt))
       (if param
         (progn
           (setq segment-idx (fix param))
           (setq 2d-pt (list (car pt) (cadr pt)))
           (vla-addVertex obj (1+ segment-idx) 
             (vlax-make-variant 
               (vlax-safearray-fill 
                 (vlax-make-safearray vlax-vbDouble '(0 . 1)) 
                 2d-pt
               )
             )
           )
         )
       )
     )
    )
  )
)

(defun where-is-command (cmd)
  (if (member (strcase cmd) (atoms-family 1)) t nil)
)

(defun c:ATTACHPTS ( / *error* old-cmdecho poly-ent poly-obj ss-blocks tol i count
                        block-ent block-dxf ins-pt closest-pt dist dist-along block-name)

  ;; Обработчик ошибок
  (defun *error* (msg)
    (if (and msg (not (member msg '("Function cancelled" "quit / exit abort"))))
      (princ (strcat "\nОшибка: " msg))
    )
    (if old-cmdecho (setvar "CMDECHO" old-cmdecho))
    (vla-EndUndoMark (vla-get-ActiveDocument (vlax-get-acad-object)))
    (princ)
  )

  (setq old-cmdecho (getvar "CMDECHO"))
  (setvar "CMDECHO" 0)
  (vla-StartUndoMark (vla-get-ActiveDocument (vlax-get-acad-object)))

  ;; 1. ВЫБОР ПОЛИЛИНИИ В 1 КЛИК
  (setq poly-ent (car (entsel "\nВыберите полилинию для добавления вершин (PL-VxAdd): ")))
  (if (null poly-ent)
    (progn
      (princ "\nПолилиния не выбрана.")
      (exit)
    )
  )

  (setq poly-obj (vlax-ename->vla-object poly-ent))
  (if (not (wcmatch (vla-get-ObjectName poly-obj) "*Polyline"))
    (progn
      (princ "\nВыбранный объект не является полилинией!")
      (exit)
    )
  )

  ;; Допуск расстояния от центра блока до полилинии (0.5 ед)
  (setq tol 0.5)

  ;; 2. АВТОМАТИЧЕСКИЙ СКАНЕР ВСЕХ БЛОКОВ
  (setq ss-blocks (ssget "X" '((0 . "INSERT"))))

  (if (and ss-blocks (> (sslength ss-blocks) 0))
    (progn
      (setq count 0)
      (setq i 0)

      (princ "\n-----------------------------------------------------------")
      (princ "\n№ | Имя блока       | Расстояние по полилинии | Статус PL-VxAdd")
      (princ "\n-----------------------------------------------------------")

      (repeat (sslength ss-blocks)
        (setq block-ent (ssname ss-blocks i))
        (setq block-dxf (entget block-ent))
        (setq ins-pt (cdr (assoc 10 block-dxf))) ; Центр / точка вставки блока
        (setq block-name (cdr (assoc 2 block-dxf)))

        ;; Проекция центра блока на полилинию
        (setq closest-pt (vlax-curve-getClosestPointTo poly-obj ins-pt))
        (setq dist (distance (list (car ins-pt) (cadr ins-pt))
                             (list (car closest-pt) (cadr closest-pt))))

        ;; Если центр блока на полилинии
        (if (<= dist tol)
          (progn
            (setq count (1+ count))
            (setq dist-along (vlax-curve-getDistAtPoint poly-obj closest-pt))

            ;; ВСТАВКА ВЕРШИНЫ В ПОЛИЛИНИЮ (БЕЗ ТОЧЕК И СЛОЕВ)
            (_AddVertexToPolyline poly-ent closest-pt)

            (princ (strcat "\n" (itoa count) " | " 
                           block-name 
                           (if (< (strlen block-name) 12) "\t\t| " "\t| ")
                           (rtos dist-along 2 3) " м\t\t| ВЕРШИНА ВСТАВЛЕНА"))
          )
        )
        (setq i (1+ i))
      )

      (princ "\n-----------------------------------------------------------")
      (princ (strcat "\n[PL-VxAdd] Успешно! Добавлено вершин в полилинию: " (itoa count)))
      (princ "\nЛишние слои и объекты POINT не создавались.")
    )
    (princ "\nБлоки на чертеже не найдены.")
  )

  (*error* nil)
  (princ)
)

;; Быстрый алиас команды
(defun c:AP () (c:ATTACHPTS))

(princ "\nУтилита PL-VxAdd ATTACHPTS (быстрый вызов AP) успешно загружена!")
(princ "\nВведите AP и кликните по полилинии.")
(princ)
