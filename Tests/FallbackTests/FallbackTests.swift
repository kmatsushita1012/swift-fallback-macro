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

struct FallbackTests {
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
