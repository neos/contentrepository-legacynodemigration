@contentrepository
Feature: Exceptional cases during migrations

  Background:
    Given I use no content dimensions
    And the following NodeTypes to define content repository "default":
    """
    'unstructured': []
    'Some.Package:SomeNodeType':
      properties:
        'text':
          type: string
          defaultValue: 'My default text'
    'Some.Package:SomeOtherNodeType': []
    """

  Scenario: Node variant with different type
    Given I use the following content dimensions to override content repository "default":
      | Identifier | Default | Values     | Generalizations |
      | language   | en      | en, de, ch | ch->de          |
    When I have the following node data rows:
      | Identifier    | Path             | Node Type                      | Dimension Values     |
      | sites-node-id | /sites           | unstructured                   |                      |
      | site-node-id  | /sites/test-site | Some.Package:SomeNodeType      | {"language": ["de"]} |
      | site-node-id  | /sites/test-site | Some.Package:SomeOtherNodeType | {"language": ["en"]} |
    And I run the event migration
    Then I expect a MigrationError with the message
    """
    Node aggregate with id "site-node-id" has a type of "Some.Package:SomeOtherNodeType" in content dimension [{"language":"en"}]. I was visited previously for content dimension [{"language":"de"}] with the type "Some.Package:SomeNodeType". Node variants must not have different types
    """

  Scenario: Node with missing parent
    When I have the following node data rows:
      | Identifier | Path       |
      | sites      | /sites     |
      | a          | /sites/a   |
      | c          | /sites/b/c |
    And I run the event migration
    Then I expect a MigrationError with the message
    """
    Failed to find parent node for node with id "c" and dimensions: []. Did you properly configure your dimensions setup to be in sync with the old setup?
    """

  # TODO: is it possible that nodes are processed in an order where a ancestor node is processed after a child node? -> in that case the following example should work (i.e. the scenario should fail)
  Scenario: Nodes out of order
    When I have the following node data rows:
      | Identifier | Path       |
      | sites      | /sites     |
      | a          | /sites/a   |
      | c          | /sites/b/c |
      | b          | /sites/b   |
    And I run the event migration
    Then I expect a MigrationError with the message
    """
    Failed to find parent node for node with id "c" and dimensions: []. Did you properly configure your dimensions setup to be in sync with the old setup?
    """

  Scenario: Invalid dimension configuration (unknown value)
    Given I use the following content dimensions to override content repository "default":
      | Identifier | Default | Values     | Generalizations |
      | language   | en      | en, de, ch | ch->de          |
    When I have the following node data rows:
      | Identifier | Path     | Dimension Values          |
      | sites      | /sites   |                           |
      | a          | /sites/a | {"language": ["unknown"]} |
    And I run the event migration
    Then I expect a MigrationError

  Scenario: Invalid dimension configuration (no json)
    When I have the following node data rows:
      | Identifier | Path     | Dimension Values |
      | sites      | /sites   |                  |
      | a          | /sites/a | not json         |
    And I run the event migration
    Then I expect a MigrationError

  Scenario: Invalid node properties (no JSON)
    When I have the following node data rows:
      | Identifier | Path     | Properties | Node Type                 |
      | sites      | /sites   |            |                           |
      | a          | /sites/a | not json   | Some.Package:SomeNodeType |
    And I run the event migration
    Then I expect a MigrationError with the message
    """
    Failed to decode properties "not json" of node "a" (type: "Some.Package:SomeNodeType")
    """

  Scenario: Node variants with the same dimension
    Given I use the following content dimensions to override content repository "default":
      | Identifier | Default | Values     | Generalizations |
      | language   | en      | en, de, ch | ch->de          |
    When I have the following node data rows:
      | Identifier    | Path             | Dimension Values     |
      | sites-node-id | /sites           |                      |
      | site-node-id  | /sites/test-site | {"language": ["de"]} |
      | site-node-id  | /sites/test-site | {"language": ["ch"]} |
      | site-node-id  | /sites/test-site | {"language": ["ch"]} |
    And I run the event migration
    Then I expect a MigrationError with the message
    """
    Node "site-node-id" with dimension space point "{"language":"ch"}" was already visited before
    """

  Scenario: Duplicate nodes
    Given I use the following content dimensions to override content repository "default":
      | Identifier | Default | Values     | Generalizations |
      | language   | en      | en, de, ch | ch->de          |
    When I have the following node data rows:
      | Identifier    | Path             | Dimension Values     |
      | sites-node-id | /sites           |                      |
      | site-node-id  | /sites/test-site | {"language": ["de"]} |
      | site-node-id  | /sites/test-site | {"language": ["de"]} |
    And I run the event migration
    Then I expect a MigrationError with the message
    """
    Node "site-node-id" for dimension {"language":"de"} was already created previously
    """
