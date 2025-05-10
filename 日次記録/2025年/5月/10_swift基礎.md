- JSONレスポンスをマッピングするstructを定義する際、
- structの変数名とJSONレスポンスのキー名が一致しない場合、
- CondingKeysをenumで定義し、case説でその差分を吸収できる（以下の例）

```
public struct Repository : Decodable {
    public var id: Int
    public var name: String
    public var fullName: String
    public var owner: User
    
    public enum CodingKeys : String, CodingKey {
        case id
        case name
        case fullName = "full_name"
        case owner
    }
}

```
