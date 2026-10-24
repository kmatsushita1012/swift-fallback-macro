import ComposableArchitecture
import Fallback
import Foundation
import Observation
import Sharing
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

@Reducer
private struct ObservableFeature {
    @ObservableState
    struct State: Equatable {
        @Shared var parent: Parent

        @Fallback(\ObservableFeature.State.parent.child)
        @ObservationStateIgnored
        var child: Child

        @Fallback(select: { (state: State) in state.parent.context.district })
        @ObservationStateIgnored
        var district: String

        init(parent: Shared<Parent>, initialChild: Child, initialDistrict: String = "local district") {
            self._parent = parent
            self._child = initialChild
            self._district = initialDistrict
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

@Suite(.serialized)
struct FallbackIntegrationTests {
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

    @Test func `shared changes are read dynamically and fallback does not write shared value`() {
        let sharedParent = Shared(value: Parent(context: Context(child: nil, district: nil)))
        var first = ObservableFeature.State(parent: sharedParent, initialChild: Child(name: "local"))
        let second = ObservableFeature.State(parent: sharedParent, initialChild: Child(name: "other local"))

        #expect(first.child.name == "local")
        #expect(first.district == "local district")
        first.child = Child(name: "updated local")
        #expect(first.child.name == "updated local")
        #expect(first.parent.child == nil)

        first.$parent.withLock { $0.child = Child(name: "shared") }
        #expect(first.child.name == "shared")
        #expect(second.child.name == "shared")

        first.$parent.withLock {
            $0.child = nil
            $0.context.district = "shared district"
        }
        #expect(first.child.name == "updated local")
        #expect(second.child.name == "other local")
        #expect(first.district == "shared district")
        #expect(second.district == "shared district")

        first.$parent.withLock { $0.context.district = nil }
        #expect(first.district == "local district")
        #expect(second.district == "local district")
    }

    @Test func `observable state tracks fallback and shared changes`() {
        let sharedParent = Shared(value: Parent(context: Context(child: nil, district: nil)))
        var state = ObservableFeature.State(parent: sharedParent, initialChild: Child(name: "initial"))
        let didChange = ChangeFlag()

        withObservationTracking {
            _ = state.child
        } onChange: {
            didChange.set()
        }

        state.child = Child(name: "updated")
        #expect(didChange.value, "Writing the local fallback should invalidate an observation of child")

        didChange.reset()
        withObservationTracking {
            _ = state.child
        } onChange: {
            didChange.set()
        }

        state.$parent.withLock { $0.child = Child(name: "shared") }
        #expect(didChange.value, "Updating the shared reference should invalidate an observation of child")
        #expect(state.child.name == "shared")

        didChange.reset()
        withObservationTracking {
            _ = state.district
        } onChange: {
            didChange.set()
        }

        state.$parent.withLock { $0.context.district = "shared district" }
        #expect(didChange.value, "Updating the shared reference should invalidate an observation of the selected closure value")
        #expect(state.district == "shared district")
    }

    @Test @MainActor func `reducer writes fallback without changing shared parent`() async {
        let parent = Shared(value: Parent(context: Context(child: nil, district: nil)))
        let store = TestStore(
            initialState: ObservableFeature.State(parent: parent, initialChild: Child(name: "initial"))
        ) {
            ObservableFeature()
        }

        await store.send(.setChild(Child(name: "updated"))) {
            $0.child = Child(name: "updated")
        }
        #expect(parent.wrappedValue.child == nil)
        let childName = store.state.child.name
        #expect(childName == "updated")
    }
}
