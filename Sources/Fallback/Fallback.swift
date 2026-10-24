/// Reads a value through a key path when that value is non-`nil`, and otherwise
/// reads and writes a local fallback value.
///
/// The argument must identify an optional property. The annotated property must
/// be a mutable stored property with an explicit type inside a structure.
/// Initialize the fallback storage from the structure's initializer:
///
/// ```swift
/// struct State {
///   let parent: Parent
///   @Fallback(\State.parent.child) var child: Child
///
///   init(parent: Parent, initialChild: Child) {
///     self.parent = parent
///     self._child = initialChild
///   }
/// }
/// ```
///
/// The key path must spell out its root type (for example, `\State.parent.child`)
/// because Swift cannot infer that type from an attached macro argument.
///
/// Assigning to `child` changes only its fallback storage. The referenced
/// property is read again on each access, so changes to shared or observable
/// state are reflected by the next read.
@attached(accessor)
@attached(peer, names: prefixed(_))
public macro Fallback(_ keyPath: AnyKeyPath) =
    #externalMacro(module: "FallbackMacros", type: "FallbackMacro")
