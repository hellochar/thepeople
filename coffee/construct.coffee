define [], () ->
  # http://stackoverflow.com/questions/1606797/use-of-apply-with-new-operator-is-this-possible
  construct = (constructor, args) ->
    switch args.length
      when 0 then return new constructor()
      when 1 then return new constructor(args[0])
      when 2 then return new constructor(args[0], args[1])
      when 3 then return new constructor(args[0], args[1], args[2])
      else throw "Constructor with arity #{args.length} not implemented yet!"

  construct
