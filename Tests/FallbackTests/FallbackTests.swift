import Fallback
import XCTest

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

final class FallbackTests: XCTestCase {
    func testNilReferenceReturnsLocalValueAndWritesOnlyLocalValue() {
        var model = Model(
            parent: Parent(context: Context(child: nil, district: nil)),
            child: Child(name: "local"),
            district: "local district"
        )

        XCTAssertEqual(model.child.name, "local")
        XCTAssertEqual(model.district, "local district")

        model.child = Child(name: "updated local")
        model.district = "updated district"

        XCTAssertEqual(model.child.name, "updated local")
        XCTAssertNil(model.parent.child)
        XCTAssertEqual(model.district, "updated district")
        XCTAssertNil(model.parent.context.district)
    }

    func testNonNilReferenceWinsAndLocalValueSurvivesReferenceTransitions() {
        var model = Model(
            parent: Parent(context: Context(child: Child(name: "remote"), district: "remote district")),
            child: Child(name: "local"),
            district: "local district"
        )

        XCTAssertEqual(model.child.name, "remote")
        XCTAssertEqual(model.district, "remote district")

        model.child = Child(name: "new local")
        model.district = "new local district"
        XCTAssertEqual(model.child.name, "remote")
        XCTAssertEqual(model.district, "remote district")

        model.parent.child = nil
        model.parent.context.district = nil
        XCTAssertEqual(model.child.name, "new local")
        XCTAssertEqual(model.district, "new local district")

        model.parent.child = Child(name: "remote again")
        XCTAssertEqual(model.child.name, "remote again")

        model.parent.child = nil
        XCTAssertEqual(model.child.name, "new local")
    }
}
