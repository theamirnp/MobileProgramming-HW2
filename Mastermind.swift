import Foundation

enum GameFeedback: String {
    case correctPositionAndValue = "⚫️"
    case correctValueOnly = "⚪️"
}

enum GuessValidationError: Error {
    case invalidLength
    case nonNumericCharacters
    case outOfRangeDigits
}

struct MastermindGame {
    private let secretCode: [Int]
    private let codeLength: Int = 4
    private let digitRange: ClosedRange<Int> = 1...6

    init() {
        self.secretCode = MastermindGame.generateSecretCode(length: codeLength, range: digitRange)
    }

    private static func generateSecretCode(length: Int, range: ClosedRange<Int>) -> [Int] {
        return (0..<length).map { _ in Int.random(in: range) }
    }

    private func processUserInput(_ input: String) -> Result<[Int], GuessValidationError> {
        guard input.count == codeLength else {
            return .failure(.invalidLength)
        }
        
        guard input.allSatisfy({ $0.isNumber }) else {
            return .failure(.nonNumericCharacters)
        }
        
        let guessedDigits = input.compactMap { $0.wholeNumberValue }
        
        guard guessedDigits.count == codeLength && guessedDigits.allSatisfy({ digitRange.contains($0) }) else {
            return .failure(.outOfRangeDigits)
        }
        
        return .success(guessedDigits)
    }

    func evaluateGuess(_ guess: [Int]) -> [GameFeedback] {
        var blackPegs = 0
        var whitePegs = 0
        var codeCopy = self.secretCode
        var guessCopy = guess
        
        for i in 0..<codeLength {
            if guessCopy[i] == codeCopy[i] {
                blackPegs += 1
                codeCopy[i] = -1
                guessCopy[i] = -2
            }
        }
        
        for i in 0..<codeLength {
            if guessCopy[i] > 0, let j = codeCopy.firstIndex(of: guessCopy[i]) {
                whitePegs += 1
                codeCopy[j] = -1
                guessCopy[i] = -2
            }
        }

        let blackFeedback = Array(repeating: GameFeedback.correctPositionAndValue, count: blackPegs)
        let whiteFeedback = Array(repeating: GameFeedback.correctValueOnly, count: whitePegs)
        
        return blackFeedback + whiteFeedback
    }

    func run() {
        displayWelcomeMessage()
        
        var hasWon = false
        var attempts = 0

        while !hasWon {
            attempts += 1
            print("\n[\(attempts)] Enter your guess (a 4-digit number between 1 and 6):")
            
            guard let userInput = readLine() else { continue }
            
            if userInput.lowercased() == "exit" {
                print("You have quit the game. Goodbye!")
                break
            }
            
            let validationResult = processUserInput(userInput)
            
            switch validationResult {
            case .success(let guessedCode):
                let currentFeedback = evaluateGuess(guessedCode)
                
                if currentFeedback.filter({ $0 == .correctPositionAndValue }).count == codeLength {
                    hasWon = true
                    print("\n🎉 Congratulations! You won! 🎉")
                } else {
                    displayFeedback(currentFeedback)
                }
                
            case .failure(let error):
                displayError(error)
            }
        }
        
        print("The secret code was: \(secretCode.map(String.init).joined())")
    }
    
    private func displayWelcomeMessage() {
        print("=======================================")
        print("    Welcome to the Mastermind Game!    ")
        print("=======================================")
        print("You must guess a secret 4-digit code.")
        print("The digits are between 1 and 6.")
        print("\(GameFeedback.correctPositionAndValue.rawValue): Correct digit in the correct position.")
        print("\(GameFeedback.correctValueOnly.rawValue): Correct digit in the wrong position.")
        print("Type 'exit' to quit the game at any time.")
    }
    
    private func displayFeedback(_ feedback: [GameFeedback]) {
        if feedback.isEmpty {
            print("Result: No correct digits.")
        } else {
            let feedbackString = feedback.map { $0.rawValue }.joined(separator: " ")
            print("Result: \(feedbackString)")
        }
    }

    private func displayError(_ error: GuessValidationError) {
        switch error {
        case .invalidLength:
            print("Error: Your guess must be exactly \(codeLength) digits long.")
        case .nonNumericCharacters:
            print("Error: Your guess must only contain numbers.")
        case .outOfRangeDigits:
            print("Error: All digits must be between \(digitRange.lowerBound) and \(digitRange.upperBound).")
        }
    }
}

let newGame = MastermindGame()
newGame.run()