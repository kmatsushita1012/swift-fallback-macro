import ComposableArchitecture
import Fallback
import Observation
import Sharing
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

@Reducer
private struct ObservableFeature {
    @ObservableState
    struct State: Equatable {
        @Shared var parent: Parent

        @Fallback(\ObservableFeature.State.parent.child)
        @ObservationStateIgnored
        var child: Child

        init(parent: Shared<Parent>, initialChild: Child) {
            self._parent = parent
            self._child = initialChild
        }
    }

    enum Action {
        case setChild(Child)
    }

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case let .setChild(child):
                state.child = child
                return .none
            }
        }
    }
}

final class FallbackIntegrationTests: XCTestCase {
    private final class ChangeFlag: @unchecked Sendable {
        private let lock = NSLock()
        private var changed = false

        var value: Bool {
            lock.lock()
            defer { lock.unlock() }
            return changed
        }

        func set() {
            lock.lock()
            defer { lock.unlock() }
            changed = true
        }

        func reset() {
            lock.lock()
            defer { lock.unlock() }
            changed = false
        }
    }

    func testSharedChangesAreReadDynamicallyAndFallbackDoesNotWriteSharedValue() {
        let sharedParent = Shared(value: Parent(context: Context(child: nil, district: nil)))
        var first = ObservableFeature.State(parent: sharedParent, initialChild: Child(name: "local"))
        let second = ObservableFeature.State(parent: sharedParent, initialChild: Child(name: "other local"))

        XCTAssertEqual(first.child.name, "local")
        first.child = Child(name: "updated local")
        XCTAssertEqual(first.child.name, "updated local")
        XCTAssertNil(first.parent.child)

        first.$parent.withLock { $0.child = Child(name: "shared") }
        XCTAssertEqual(first.child.name, "shared")
        XCTAssertEqual(second.child.name, "shared")

        first.$parent.withLock { $0.child = nil }
        XCTAssertEqual(first.child.name, "updated local")
        XCTAssertEqual(second.child.name, "other local")
    }

    func testObservableStateTracksFallbackAndSharedChanges() {
        let sharedParent = Shared(value: Parent(context: Context(child: nil, district: nil)))
        var state = ObservableFeature.State(parent: sharedParent, initialChild: Child(name: "initial"))
        let didChange = ChangeFlag()

        withObservationTracking {
            _ = state.child
        } onChange: {
            didChange.set()
        }

        state.child = Child(name: "updated")
        XCTAssertTrue(didChange.value, "Writing the local fallback should invalidate an observation of child")

        didChange.reset()
        withObservationTracking {
            _ = state.child
        } onChange: {
            didChange.set()
        }

        state.$parent.withLock { $0.child = Child(name: "shared") }
        XCTAssertTrue(didChange.value, "Updating the shared reference should invalidate an observation of child")
        XCTAssertEqual(state.child.name, "shared")
    }

    @MainActor
    func testReducerCanWriteFallbackWithoutChangingSharedParent() async {
        let parent = Shared(value: Parent(context: Context(child: nil, district: nil)))
        let store = TestStore(
            initialState: ObservableFeature.State(parent: parent, initialChild: Child(name: "initial"))
        ) {
            ObservableFeature()
        }

        await store.send(.setChild(Child(name: "updated"))) {
            $0.child = Child(name: "updated")
        }
        XCTAssertNil(parent.wrappedValue.child)
        let childName = store.state.child.name
        XCTAssertEqual(childName, "updated")
    }
}
