package state_context

import "core:mem"


State :: struct {
    value: any,
    destructor: proc(value: any),
}


Namespace :: struct {
    name: string,
    state_map: map[string]State,
}

namespace_make :: proc(name: string, allocator := context.allocator) -> (res: Namespace, err: mem.Allocator_Error) #optional_allocator_error {
    namespace: Namespace
    namespace.name = name
    namespace.state_map = make(map[string]State, allocator = allocator) or_return
    return namespace, nil
}

namespace_destroy :: proc(namespace: ^Namespace) {
    for _, state in namespace.state_map {
        if state.destructor != nil {
            state.destructor(state.value)
        }
        free(state.value.data)
    }
    delete(namespace.state_map)
}

namespace_delete_state :: proc(namespace: ^Namespace, name: string) {
    state, exists := namespace.state_map[name]
    if !exists {
        return
    }
    if state.destructor != nil {
        state.destructor(state.value)
    }
    free(state.value.data)
    delete_key(&namespace.state_map, name)
}


Context :: struct {
    root_namespace: Namespace,
    namespace_stack: [dynamic]Namespace,
    allocator: mem.Allocator,
}

context_make :: proc(allocator := context.allocator) -> (res: Context, err: mem.Allocator_Error) #optional_allocator_error {
    ctx: Context
    ctx.allocator = allocator
    ctx.root_namespace = namespace_make("Root", allocator = allocator) or_return
    ctx.namespace_stack = make([dynamic]Namespace, allocator = allocator) or_return
    append(&ctx.namespace_stack, ctx.root_namespace)
    return ctx, nil
}

context_destroy :: proc(ctx: ^Context) {
    namespace_destroy(&ctx.root_namespace)
    delete(ctx.namespace_stack)
}

current_namespace :: proc(ctx: ^Context) -> ^Namespace {
    return &ctx.namespace_stack[len(ctx.namespace_stack) - 1]
}

get_state :: proc(ctx: ^Context, name: string, default: $T, destructor: proc(value: any) = nil) -> ^T {
    namespace := current_namespace(ctx)
    state, ok := namespace.state_map[name]
    if !ok {
        value := new(T, ctx.allocator)
        value^ = default
        namespace.state_map[name] = State{value, destructor}
        return value
    }
    return state.value.(^T)
}

begin_namespace :: proc(ctx: ^Context, name: string) {
    namespace := get_state(ctx, name, namespace_make(name, ctx.allocator), destructor = proc(value: any) {
        namespace_destroy(value.(^Namespace))
    })
    append(&ctx.namespace_stack, namespace^)
}

end_namespace :: proc(ctx: ^Context) {
    pop(&ctx.namespace_stack)
}

context_delete_state :: proc(ctx: ^Context, name: string) {
    namespace_delete_state(current_namespace(ctx), name)
}

delete_state :: proc{
    context_delete_state,
    namespace_delete_state,
}