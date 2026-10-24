import Fallback
import Testing

private struct Child: Equatable, Sendable {
    var name: String
}

private struct Context: Equatable, Sendable {
    var child: Child?
    var district: String?
}

private struct Parent: Equatable, Sendable {
    var context: Context

    var child: Child? {
        get { context.child }
        set { context.child = newValue }
    }
}

private struct Model {
    var parent: Parent

    @Fallback(\Model.parent.child)
    var child: Child

    @Fallback(\Model.parent.context.district)
    var district: String

    init(parent: Parent, child: Child, district: String) {
        self.parent = parent
        self._child = child
        self._district = district
    }
}

private struct ClosureModel {
    var parent: Parent

    @Fallback(select: { (state: ClosureModel) in state.parent.child })
    var child: Child

    init(parent: Parent, child: Child) {
        self.parent = parent
        self._child = child
    }
}

private struct FunctionSelectorModel {
    var parent: Parent

    @Fallback(select: selectFunctionChild)
    var child: Child

    init(parent: Parent, child: Child) {
        self.parent = parent
        self._child = child
    }
}

private func selectFunctionChild(_ state: FunctionSelectorModel) -> Child? {
    state.parent.child
}

struct FallbackTests {
    @Test func `selector closure reads the reference and falls back to local storage`() {
        var model = ClosureModel(
            parent: Parent(context: Context(child: nil, district: nil)),
            child: Child(name: "local")
        )

        #expect(model.child.name == "local")
        model.child = Child(name: "updated local")
        #expect(model.child.name == "updated local")
        #expect(model.parent.child == nil)

        model.parent.child = Child(name: "remote")
        #expect(model.child.name == "remote")

        model.parent.child = nil
        #expect(model.child.name == "updated local")
    }

    @Test func `selector function can be passed by name`() {
        var model = FunctionSelectorModel(
            parent: Parent(context: Context(child: nil, district: nil)),
            child: Child(name: "local")
        )

        #expect(model.child.name == "local")
        model.parent.child = Child(name: "remote")
        #expect(model.child.name == "remote")
    }

    @Test func `nil reference returns local value and writes only local value`() {
        var model = Model(
            parent: Parent(context: Context(child: nil, district: nil)),
            child: Child(name: "local"),
            district: "local district"
        )

        #expect(model.child.name == "local")
        #expect(model.district == "local district")

        model.child = Child(name: "updated local")
        model.district = "updated district"

        #expect(model.child.name == "updated local")
        #expect(model.parent.child == nil)
        #expect(model.district == "updated district")
        #expect(model.parent.context.district == nil)
    }

    @Test func `non-nil reference wins while local value survives transitions`() {
        var model = Model(
            parent: Parent(context: Context(child: Child(name: "remote"), district: "remote district")),
            child: Child(name: "local"),
            district: "local district"
        )

        #expect(model.child.name == "remote")
        #expect(model.district == "remote district")

        model.child = Child(name: "new local")
        model.district = "new local district"
        #expect(model.child.name == "remote")
        #expect(model.district == "remote district")

        model.parent.child = nil
        model.parent.context.district = nil
        #expect(model.child.name == "new local")
        #expect(model.district == "new local district")

        model.parent.child = Child(name: "remote again")
        #expect(model.child.name == "remote again")

        model.parent.child = nil
        #expect(model.child.name == "new local")
    }
}
