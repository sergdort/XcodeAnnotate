# List Styling And Tables

For identity and row invalidation, use the Apple ForEach reference selected by `../SKILL.md`. This file covers list presentation and tables only.

## List with Custom Styling

```swift
// Remove default background and separators
List(items) { item in
    ItemRow(item: item)
        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
        .listRowSeparator(.hidden)
}
.listStyle(.plain)
.scrollContentBackground(.hidden)
.background(Color.customBackground)
.environment(\.defaultMinListRowHeight, 1)  // Allows custom row heights
```

## List with Pull-to-Refresh

```swift
List(items) { item in
    ItemRow(item: item)
}
.refreshable {
    await loadItems()
}
```

## Empty States with ContentUnavailableView (iOS 17+)

Use `ContentUnavailableView` for empty list/search states. The built-in `.search` variant is auto-localized:

```swift
List {
    ForEach(searchResults) { item in
        ItemRow(item: item)
    }
}
.overlay {
    if searchResults.isEmpty, !searchText.isEmpty {
        ContentUnavailableView.search(text: searchText)
    }
}
```

For non-search empty states, use a custom instance:

```swift
ContentUnavailableView(
    "No Articles",
    systemImage: "doc.richtext.fill",
    description: Text("Articles you save will appear here.")
)
```

## Custom List Backgrounds

Use `.scrollContentBackground(.hidden)` to replace the default list background:

```swift
List(items) { item in
    ItemRow(item: item)
}
.scrollContentBackground(.hidden)
.background(Color.customBackground)
```

Without `.scrollContentBackground(.hidden)`, a custom `.background()` has no visible effect on `List`.

## Table

> **Availability:** iOS 16.0+, iPadOS 16.0+, visionOS 1.0+

A multi-column data container that presents rows of `Identifiable` data with sortable, selectable columns. On compact size classes (iPhone, iPad Slide Over), columns after the first are automatically hidden.

### Basic Table

```swift
struct Person: Identifiable {
    let givenName: String
    let familyName: String
    let emailAddress: String
    let id = UUID()
    var fullName: String { givenName + " " + familyName }
}

struct PeopleTable: View {
    @State private var people: [Person] = [ /* ... */ ]

    var body: some View {
        Table(people) {
            TableColumn("Given Name", value: \.givenName)
            TableColumn("Family Name", value: \.familyName)
            TableColumn("E-Mail Address", value: \.emailAddress)
        }
    }
}
```

### Table with Selection

Bind to a single `ID` for single-selection, or a `Set<ID>` for multi-selection:

```swift
struct SelectableTable: View {
    @State private var people: [Person] = [ /* ... */ ]
    @State private var selectedPeople = Set<Person.ID>()

    var body: some View {
        Table(people, selection: $selectedPeople) {
            TableColumn("Given Name", value: \.givenName)
            TableColumn("Family Name", value: \.familyName)
            TableColumn("E-Mail Address", value: \.emailAddress)
        }
        Text("\(selectedPeople.count) people selected")
    }
}
```

### Sortable Table

Provide a binding to `[KeyPathComparator]` and re-sort the data in `.onChange(of:)`:

```swift
struct SortableTable: View {
    @State private var people: [Person] = [ /* ... */ ]
    @State private var sortOrder = [KeyPathComparator(\Person.givenName)]

    var body: some View {
        Table(people, sortOrder: $sortOrder) {
            TableColumn("Given Name", value: \.givenName)
            TableColumn("Family Name", value: \.familyName)
            TableColumn("E-Mail Address", value: \.emailAddress)
        }
        .onChange(of: sortOrder) { _, newOrder in
            people.sort(using: newOrder)
        }
    }
}
```

**Important:** The table does **not** sort data itself — you must re-sort the collection when `sortOrder` changes.

### Adaptive Table for Compact Size Classes

On iPhone or iPad in Slide Over, only the first column is shown. Customize it to display combined information:

```swift
struct AdaptiveTable: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    private var isCompact: Bool { horizontalSizeClass == .compact }

    @State private var people: [Person] = [ /* ... */ ]
    @State private var sortOrder = [KeyPathComparator(\Person.givenName)]

    var body: some View {
        Table(people, sortOrder: $sortOrder) {
            TableColumn("Given Name", value: \.givenName) { person in
                VStack(alignment: .leading) {
                    Text(isCompact ? person.fullName : person.givenName)
                    if isCompact {
                        Text(person.emailAddress)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            TableColumn("Family Name", value: \.familyName)
            TableColumn("E-Mail Address", value: \.emailAddress)
        }
        .onChange(of: sortOrder) { _, newOrder in
            people.sort(using: newOrder)
        }
    }
}
```

### Table with Static Rows

Use `init(of:columns:rows:)` when rows are known at compile time:

```swift
struct Purchase: Identifiable {
    let price: Decimal
    let id = UUID()
}

struct TipTable: View {
    let currencyStyle = Decimal.FormatStyle.Currency(code: "USD")

    var body: some View {
        Table(of: Purchase.self) {
            TableColumn("Base price") { purchase in
                Text(purchase.price, format: currencyStyle)
            }
            TableColumn("With 15% tip") { purchase in
                Text(purchase.price * 1.15, format: currencyStyle)
            }
            TableColumn("With 20% tip") { purchase in
                Text(purchase.price * 1.2, format: currencyStyle)
            }
        } rows: {
            TableRow(Purchase(price: 20))
            TableRow(Purchase(price: 50))
            TableRow(Purchase(price: 75))
        }
    }
}
```

### Table with Dynamic Number of Columns

> **Availability:** iOS 17.4+, iPadOS 17.4+, Mac Catalyst 17.4+, macOS 14.4+, visionOS 1.1+

If the number of columns is not known at runtime use `TableColumnForEach` to create columns based on a `RandomAccessCollection` of some data type. Either the collection’s elements must conform to `Identifiable` or you need to provide an id parameter to the `TableColumnForEach` initializer.

This can be mixed with static compile time known `TableColumn` usage.

```swift
struct AudioChannel: Identifiable {
    let name: String
    let id: UUID
}

struct AudioSample: Identifiable {
    let id: UUID
    let timestamp: TimeInterval
    func level(channel: AudioChannel.ID) -> Double {
        1
    }
}

@Observable
class AudioSampleTrack {
    let channels: [AudioChannel]
    var samples: [AudioSample]
}

struct ContentView: View {
    var track: AudioSampleTrack

    var body: some View {
        Table(track.samples) {
            TableColumn("Timestamp (ms)") { sample in
                Text(sample.timestamp, format: .number.scale(1000))
                    .monospacedDigit()
            }
            TableColumnForEach(track.channels) { channel in
                TableColumn(channel.name) { sample in
                    Text(sample.level(channel: channel.id),
                         format: .number.precision(.fractionLength(2))
                    )
                    .monospacedDigit()
                }
                .width(ideal: 70)
                .alignment(.numeric)
            }
        }
    }
}
```

### Table Styles

```swift
// Inset (no borders)
Table(people) { /* columns */ }
    .tableStyle(.inset)

// Hide column headers
Table(people) { /* columns */ }
    .tableColumnHeaders(.hidden)
```

### Platform Behavior

| Platform | Behavior |
|----------|----------|
| **iPadOS (regular)** | Full multi-column layout; headers and all columns visible |
| **iPadOS (compact)** | Only the first column shown; headers hidden |
| **iPhone (all sizes)** | Only the first column shown; headers hidden; list-like appearance |

> **Best Practice:** Prefer handling the compact size class by showing combined info in the first column. This provides a seamless transition when the size class changes (e.g., entering/exiting Slide Over on iPad).
