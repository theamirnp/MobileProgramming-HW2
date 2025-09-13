import Foundation


enum APIError: Error, LocalizedError {
    case invalidURL
    case requestFailed(Error)
    case nonHTTPSuccess(statusCode: Int, body: String?)
    case decodingError(Error)
    case noData

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "The provided URL is invalid."
        case .requestFailed(let error):
            return "Network request failed: \(error.localizedDescription)"
        case .nonHTTPSuccess(let statusCode, let body):
            let bodyString = body ?? "No body content"
            return "Server responded with a non-success status code: \(statusCode). Body: \(bodyString)"
        case .decodingError(let error):
            return "Failed to decode the JSON response: \(error.localizedDescription)"
        case .noData:
            return "Server did not return any data."
        }
    }
}

struct GameResponse: Codable {
    let gameID: String

    enum CodingKeys: String, CodingKey {
        case gameID = "game_id"
    }
}

struct GuessRequest: Codable {
    let gameID: String
    let guess: String

    enum CodingKeys: String, CodingKey {
        case gameID = "game_id"
        case guess
    }
}

struct GuessResponse: Codable {
    let black: Int
    let white: Int
}


class APIService {
    private let baseURL = "https://mastermind.darkube.app"
    
    func startGame() async throws -> String {
        guard let url = URL(string: "\(baseURL)/game") else {
            throw APIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
            let body = String(data: data, encoding: .utf8)
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1
            throw APIError.nonHTTPSuccess(statusCode: statusCode, body: body)
        }

        do {
            let gameResponse = try JSONDecoder().decode(GameResponse.self, from: data)
            return gameResponse.gameID
        } catch {
            throw APIError.decodingError(error)
        }
    }
    
    func makeGuess(gameID: String, guess: [Int]) async throws -> GuessResponse {
        guard let url = URL(string: "\(baseURL)/guess") else {
            throw APIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let guessString = guess.map(String.init).joined()
        let requestBody = GuessRequest(gameID: gameID, guess: guessString)
        request.httpBody = try JSONEncoder().encode(requestBody)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
            let body = String(data: data, encoding: .utf8)
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1
            throw APIError.nonHTTPSuccess(statusCode: statusCode, body: body)
        }
        
        do {
            let guessResponse = try JSONDecoder().decode(GuessResponse.self, from: data)
            return guessResponse
        } catch {
            throw APIError.decodingError(error)
        }
    }
}


class GameController {
    private let apiService = APIService()
    private var gameID: String?

    @main
    static func main() async {
        let game = GameController()
        await game.play()
    }

    func play() async {
        print("🎮 Welcome to Mastermind! 🎮")
        print("Rules: Guess a 4-digit code with numbers between 1 and 6.")
        print("To quit the game, type 'exit'.")
        print("--------------------------------------------------")

        do {
            print("⏳ Creating a new game...")
            self.gameID = try await apiService.startGame()
            print("✅ Game started successfully. Game ID: \(gameID!)")
        } catch {
            print("❌ Error starting game: \(error.localizedDescription)")
            return
        }

        guard let gameID = self.gameID else {
             print("❌ Failed to get Game ID. Stopping the game.")
             return
        }
        
        var attempts = 0
        while true {
            attempts += 1
            print("\n------------------ Attempt #\(attempts) ------------------")
            print("🤔 Enter your guess (a 4-digit number):", terminator: " ")
            
            guard let input = readLine()?.trimmingCharacters(in: .whitespacesAndNewlines), !input.isEmpty else {
                print("⚠️ Invalid input. Please try again.")
                continue
            }
            
            if input.lowercased() == "exit" {
                print("👋 Goodbye!")
                break
            }
            
            guard input.count == 4, let _ = Int(input), input.allSatisfy({ "1"..."6" ~= $0 }) else {
                print("⛔️ Invalid format! Please enter a 4-digit code containing only numbers from 1 to 6.")
                continue
            }
            
            let guessArray = input.compactMap { $0.wholeNumberValue }
            
            do {
                print("📡 Sending guess to the server...")
                let result = try await apiService.makeGuess(gameID: gameID, guess: guessArray)
                
                let feedback = String(repeating: "⚫️", count: result.black) + String(repeating: "⚪️", count: result.white)
                print("Result of your guess: \(feedback)")
                
                if result.black == 4 {
                    print("\n🎉 Congratulations! You won! 🎉")
                    print("You found the code in \(attempts) attempts.")
                    break
                }
            } catch {
                print("❌ Error communicating with the server: \(error.localizedDescription)")
            }
        }
    }
}
