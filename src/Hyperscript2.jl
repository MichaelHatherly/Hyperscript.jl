#=
    actions:  normalize / validate / escape / render
    subjects: tag / attr name / attr value / child
    contexts: CSS / HTML / SVG + per-action options

    Nodes are normalized and validated on input and escaped upon output.
=#

# indentation
# isvoid
# value => val?

module Hyperscript

abstract type NodeKind end

struct CSS <: NodeKind end
struct HTML <: NodeKind end
struct SVG <: NodeKind end

struct Ctx{kind} end
isvoid(ctx, tag) = false

#=
normalization and validation of tags, attributes, and children
should function differently for each; hence there is no central
point of override for the set.

escaping of tags, attributes, and children, however, has potential
to be uniform across all three types; hence there is an `escape`
fallback for the three separate methods.
=#

normalizetag(ctx, tag) = tag
normalizeattr(ctx, tag, attr) = attr
normalizechild(ctx, tag, child) = child

validatetag(ctx, tag) = tag
validateattr(ctx, tag, attr) = attr
validatechild(ctx, tag, child) = child

escape(ctx, x) = x
escapetag(ctx, tag) = escape(ctx, tag)
escapeattr(ctx, attr) = escape(ctx, attr)
escapechild(ctx, child) = escape(ctx, child)

function flat(xs::Union{Base.Generator, Tuple, Array})
    out = []
    for x in xs
        append!(out, flat(x))
    end
    out
end
flat(x) = (x,)

# todo: are these making too many allocations?
vn_children(ctx, tag, children) =
    validatechild.(ctx, tag, normalizechild.(ctx, tag, flat(children)))
vn_attrs(ctx, tag, attrs) =
    Dict(validateattr(ctx, tag, normalizeattr(ctx, tag, attr)) for attr in attrs)

struct Node
    ctx::Ctx
    tag::String
    children::Vector{Any}
    attrs::Dict{String, String}
    function Node(ctx, tag, children, attrs)
        tag = validatetag(ctx, normalizetag(ctx, tag))
        new(ctx, tag, vn_children(ctx, tag, children), vn_attrs(ctx, tag, attrs))
    end
end

tag(x::Node) = Base.getfield(x, :tag)
attrs(x::Node) = Base.getfield(x, :attrs)
children(x::Node) = Base.getfield(x, :children)
context(x::Node) = Base.getfield(x, :ctx)

function (node::Node)(cs...; as...)
    Node(
        context(node),
        tag(node),
        isempty(cs) ? children(node) : prepend!(vn_children(context(node), tag(node), cs), children(node)),
        isempty(as) ? attrs(node)    : merge(attrs(node), vn_attrs(context(node), tag(node), as))
    )
end

render(io::IO, ctx::Ctx{HTML}, x::String) = print(io, x)

function render(io::IO, ctx::Ctx{HTML}, node::Node)
    esctag = escapetag(ctx, tag(node))
    print(io, "<", esctag)
    for attr in pairs(attrs(node))
        (name, value) = escapeattr(ctx, attr)
        print(io, " ", name, "=\"", value, "\"")
    end
    if isvoid(ctx, tag(node))
        @assert isempty(children(node))
        print(io, " />")
    else
        print(io, ">")
        for child in children(node)
            render(io, ctx, child)
        end
        print(io, "</", esctag,  ">")
    end
end

Base.show(io::IO, node::Node) = render(io, context(node), node)

m_html(tag, children...; attrs...) = Node(Ctx{HTML}(), tag, children, attrs)

###

# HTML
# note: can avoid extra stringification by overriding attr::Pair{String, String} and so forth
normalizeattr(ctx::Ctx{HTML}, tag, attr) = string(attr.first) => string(attr.second)
const m = m_html
node = m("div", align="foo", m("div", moo="false", boo=true)("xx", extra=4, boo=5))
@show node

# 1.
# Node(Ctx{HTML}(), "div", [
#     Node(Ctx{HTML}(), "div", [], Dict("moo" => "false"))
# ], Dict("align" => "true"))
# 2.
# m("div", align="foo", m("div", moo="false"))


#= questions

at what level do we want to stringify things? probably early, so we can validate the values.

what do we want to use for stringification? `string()` uses `print`.

how do we turn a single attr into multiple attrs, e.g. -webkit- and -moz- versions of a css rule?
    maybe we do this at output time.

does order matter for css rules? yes, but julia's keyword-splatting & rules about repeated keywords just make it all work out.
=#


# idea: use clojure-style :attr val :attr val pairs for the concise macro. question: how do things nest?

# isnothing(x) = x == nothing
# kebab(camel::String) = join(islower(c) || c == '-' ? c : '-' * lowercase(c) for c in camel)
# kebab(camel::Symbol) = kebab(String(camel))


#=

struct NormalizeConfig end
struct ValidateConfig end
struct EscapeConfig end

# todo: what context do the various pieces need?

# Throw an error if the thing is invalid; otherwise do nothing
function validatetag(ctx, tag)
end
function validateattr(ctx, tag, name, value)
end
function validatechild(ctx, tag, child)
end

# Return the escaped version of the thing.

=#



#=  the pipeline

    normalize => validate => escape => render

    actions:  normalize / validate / escape / render
    subjects: tag / attrname / attrvalue / child
    contexts: CSS / HTML / SVG + validation/escape options (treat nan as invalid?)

    further nuance: specific versions of the specs

    validatetag(::CSS, tag)
    validateattrname(::CSS, tag, attrname)
    validateattrvalue(::CSS, tag, attrname, attrvalue)
    validatechild(::CSS, tag, child)


    normalizetag
    normalizeattr(::CSS, name, value)
    normalizechild(::CSS, name, value)



    normalizeattrname(::CSS,
    normalizeattrvalue(:CSS,
    normalizechild(::CSS
=#


#= odd cases

code in a <script>
    js or otherwise

css in a <style>

nested svg in a html
nested html inside a foreignObject in a svg


=#

#=
design note
    at the lowest level, we should not transform user input to
    conform to any particular scheme, e.g. kebabcase. the most
    basic use should be to store input as it was provided and
    output it in the same format.

    sugar for adding attributes and children is fine; but sugar
    for e.g. class="..." should be constrained to those node types
    that support it.
=#

#=
concerns
    early-as-possible detection of errors
        invalid attributes
        invalid tagnames
        nan values

    deal with void tags [but only in html/svg!]

    html, svg, css
    scoped css — an orthogonal toolkit for creating scoped-css "components"
    css prefixing
    media queries – use tree nesting behavior rather than selector flattening to render
    prettyprinting with indentation
    html/svg attributes without value (use nothing) — but not with css.
    html escaping for html/svg
    different escaping rules for css and script tags

    think about what it might be like to make this do dom nodes rather than html nodes -- e.g. class -> className
=#



#=
    normalization
        attribute names
        attribute values
        child values

    validation
        attribute names
        attribute values
        child values

    escaping behavior
        attribute names
        attribute values
        child values

    allowed children - do we want to validate here, or just allow anything stringifiable?
        attribute names
        attribute values
        child values


    parameters
        content escaping on output
            attributes - e.g. attribute escape
            children - e.g. html escape, css/script escape
        normalization on input
            attributes - e.g. kebab case
            children
        allowed children
            css rules can nest
            css rules are unwelcome inside html/svg trees
            html trees are unwelcome inside css rules
        in fact, the only real interface between these things
        might be the stylednode concept.
=#


#=
    things you do with nodes
        render them
        add children
        add attributes

    any differences between html and svg?
        validation
    any differences betwen html/svg nodes and css nodes?
        validation
        normalization [possibly]
        rendering
        autoprefixing [may be seen as part of rendering]



=#


#=
    what is the most useful behavior for extending css nodes using function application syntax,
    or otherwise reusing them? E.g. putting one existing node inside another, or splatting one in
    (should that splat attrs?)
=#

#=
    use cases for nodes

        html node
            - can have html children, including <svg>, which can have only svg children
        svg node
            - can have svg children, including <foreignObject>, which can have only html children
        css node
=#

#= the bostock take: https://beta.observablehq.com/@mbostock/saving-svg
serialize = {
  const xmlns = "http://www.w3.org/2000/xmlns/";
  const xlinkns = "http://www.w3.org/1999/xlink";
  const svgns = "http://www.w3.org/2000/svg";
  return function serialize(svg) {
    svg = svg.cloneNode(true);
    if (!svg.hasAttributeNS(xmlns, "xmlns")) {
      svg.setAttributeNS(xmlns, "xmlns", svgns);
    }
    if (!svg.hasAttributeNS(xmlns, "xmlns:xlink")) {
      svg.setAttributeNS(xmlns, "xmlns:xlink", xlinkns);
    }
    const serializer = new window.XMLSerializer;
    const string = serializer.serializeToString(svg);
    return new Blob([string], {type: "image/svg+xml"});
  };
}
=#



# Recursively flattens generators, tuples, and arrays.
# Wraps scalars in a single-element tuple.
# todo: We could do something trait-based, so custom lazy collections can opt into compatibility
# todo: What does broadcast do? Do we want Array or AbstractArray?
# function flat

#= this may only make sense for some types of nodes — or maybe not?
function (node::Node)(cs...; as...)
    Node(
        tag(node),
        isempty(as) ? attrs(node)    : merge(attrs(node), as),
        isempty(cs) ? children(node) : prepend!(flat(cs), children(node))
    )
end
=#

# [Escape can directly write to io if more efficient]

end # module