//
//  SignalProducerLiftingSpec.swift
//  ReactiveCocoa
//
//  Created by Neil Pankey on 6/14/15.
//  Copyright © 2015 GitHub. All rights reserved.
//

import Result
import Nimble
import Quick
import ReactiveCocoa

class SignalProducerLiftingSpec: QuickSpec {
	override func spec() {
		describe("map") {
			it("should transform the values of the signal") {
				let (producer, sink) = SignalProducer<Int, NoError>.buffer()
				let mappedProducer = producer.map { String($0 + 1) }

				var lastValue: String?

				mappedProducer.startWithNext {
					lastValue = $0
					return
				}

				expect(lastValue).to(beNil())

				sink.sendNext(0)
				expect(lastValue).to(equal("1"))

				sink.sendNext(1)
				expect(lastValue).to(equal("2"))
			}
		}
		
		describe("mapError") {
			it("should transform the errors of the signal") {
				let (producer, sink) = SignalProducer<Int, TestError>.buffer()
				let producerError = NSError(domain: "com.reactivecocoa.errordomain", code: 100, userInfo: nil)
				var error: NSError?

				producer
					.mapError { _ in producerError }
					.startWithError { error = $0 }

				expect(error).to(beNil())

				sink.sendError(TestError.Default)
				expect(error).to(equal(producerError))
			}
		}

		describe("filter") {
			it("should omit values from the producer") {
				let (producer, sink) = SignalProducer<Int, NoError>.buffer()
				let mappedProducer = producer.filter { $0 % 2 == 0 }

				var lastValue: Int?

				mappedProducer.startWithNext { lastValue = $0 }

				expect(lastValue).to(beNil())

				sink.sendNext(0)
				expect(lastValue).to(equal(0))

				sink.sendNext(1)
				expect(lastValue).to(equal(0))

				sink.sendNext(2)
				expect(lastValue).to(equal(2))
			}
		}

		describe("ignoreNil") {
			it("should forward only non-nil values") {
				let (producer, sink) = SignalProducer<Int?, NoError>.buffer()
				let mappedProducer = producer.ignoreNil()

				var lastValue: Int?

				mappedProducer.startWithNext { lastValue = $0 }
				expect(lastValue).to(beNil())

				sink.sendNext(nil)
				expect(lastValue).to(beNil())

				sink.sendNext(1)
				expect(lastValue).to(equal(1))

				sink.sendNext(nil)
				expect(lastValue).to(equal(1))

				sink.sendNext(2)
				expect(lastValue).to(equal(2))
			}
		}

		describe("scan") {
			it("should incrementally accumulate a value") {
				let (baseProducer, sink) = SignalProducer<String, NoError>.buffer()
				let producer = baseProducer.scan("", +)

				var lastValue: String?

				producer.startWithNext { lastValue = $0 }

				expect(lastValue).to(beNil())

				sink.sendNext("a")
				expect(lastValue).to(equal("a"))

				sink.sendNext("bb")
				expect(lastValue).to(equal("abb"))
			}
		}

		describe("reduce") {
			it("should accumulate one value") {
				let (baseProducer, sink) = SignalProducer<Int, NoError>.buffer()
				let producer = baseProducer.reduce(1, +)

				var lastValue: Int?
				var completed = false

				producer.start { event in
					switch event {
					case let .Next(value):
						lastValue = value
					case .Completed:
						completed = true
					default:
						break
					}
				}

				expect(lastValue).to(beNil())

				sink.sendNext(1)
				expect(lastValue).to(beNil())

				sink.sendNext(2)
				expect(lastValue).to(beNil())

				expect(completed).to(beFalse())
				sink.sendCompleted()
				expect(completed).to(beTrue())

				expect(lastValue).to(equal(4))
			}

			it("should send the initial value if none are received") {
				let (baseProducer, sink) = SignalProducer<Int, NoError>.buffer()
				let producer = baseProducer.reduce(1, +)

				var lastValue: Int?
				var completed = false

				producer.start { event in
					switch event {
					case let .Next(value):
						lastValue = value
					case .Completed:
						completed = true
					default:
						break
					}
				}

				expect(lastValue).to(beNil())
				expect(completed).to(beFalse())

				sink.sendCompleted()

				expect(lastValue).to(equal(1))
				expect(completed).to(beTrue())
			}
		}

		describe("skip") {
			it("should skip initial values") {
				let (baseProducer, sink) = SignalProducer<Int, NoError>.buffer()
				let producer = baseProducer.skip(1)

				var lastValue: Int?
				producer.startWithNext { lastValue = $0 }

				expect(lastValue).to(beNil())

				sink.sendNext(1)
				expect(lastValue).to(beNil())

				sink.sendNext(2)
				expect(lastValue).to(equal(2))
			}

			it("should not skip any values when 0") {
				let (baseProducer, sink) = SignalProducer<Int, NoError>.buffer()
				let producer = baseProducer.skip(0)

				var lastValue: Int?
				producer.startWithNext { lastValue = $0 }

				expect(lastValue).to(beNil())

				sink.sendNext(1)
				expect(lastValue).to(equal(1))

				sink.sendNext(2)
				expect(lastValue).to(equal(2))
			}
		}

		describe("skipRepeats") {
			it("should skip duplicate Equatable values") {
				let (baseProducer, sink) = SignalProducer<Bool, NoError>.buffer()
				let producer = baseProducer.skipRepeats()

				var values: [Bool] = []
				producer.startWithNext { values.append($0) }

				expect(values).to(equal([]))

				sink.sendNext(true)
				expect(values).to(equal([ true ]))

				sink.sendNext(true)
				expect(values).to(equal([ true ]))

				sink.sendNext(false)
				expect(values).to(equal([ true, false ]))

				sink.sendNext(true)
				expect(values).to(equal([ true, false, true ]))
			}

			it("should skip values according to a predicate") {
				let (baseProducer, sink) = SignalProducer<String, NoError>.buffer()
				let producer = baseProducer.skipRepeats { $0.characters.count == $1.characters.count }

				var values: [String] = []
				producer.startWithNext { values.append($0) }

				expect(values).to(equal([]))

				sink.sendNext("a")
				expect(values).to(equal([ "a" ]))

				sink.sendNext("b")
				expect(values).to(equal([ "a" ]))

				sink.sendNext("cc")
				expect(values).to(equal([ "a", "cc" ]))

				sink.sendNext("d")
				expect(values).to(equal([ "a", "cc", "d" ]))
			}
		}

		describe("skipWhile") {
			var producer: SignalProducer<Int, NoError>!
			var sink: Signal<Int, NoError>.Observer!

			var lastValue: Int?

			beforeEach {
				let (baseProducer, observer) = SignalProducer<Int, NoError>.buffer()

				producer = baseProducer.skipWhile { $0 < 2 }
				sink = observer
				lastValue = nil

				producer.startWithNext { lastValue = $0 }
			}

			it("should skip while the predicate is true") {
				expect(lastValue).to(beNil())

				sink.sendNext(1)
				expect(lastValue).to(beNil())

				sink.sendNext(2)
				expect(lastValue).to(equal(2))

				sink.sendNext(0)
				expect(lastValue).to(equal(0))
			}

			it("should not skip any values when the predicate starts false") {
				expect(lastValue).to(beNil())

				sink.sendNext(3)
				expect(lastValue).to(equal(3))

				sink.sendNext(1)
				expect(lastValue).to(equal(1))
			}
		}

		describe("take") {
			it("should take initial values") {
				let (baseProducer, sink) = SignalProducer<Int, NoError>.buffer()
				let producer = baseProducer.take(2)

				var lastValue: Int?
				var completed = false
				producer.start { event in
					switch event {
					case let .Next(value):
						lastValue = value
					case .Completed:
						completed = true
					default:
						break
					}
				}

				expect(lastValue).to(beNil())
				expect(completed).to(beFalse())

				sink.sendNext(1)
				expect(lastValue).to(equal(1))
				expect(completed).to(beFalse())

				sink.sendNext(2)
				expect(lastValue).to(equal(2))
				expect(completed).to(beTrue())
			}
			
			it("should complete immediately after taking given number of values") {
				let numbers = [ 1, 2, 4, 4, 5 ]
				let testScheduler = TestScheduler()
				
				let producer: SignalProducer<Int, NoError> = SignalProducer { observer, _ in
					// workaround `Class declaration cannot close over value 'observer' defined in outer scope`
					let sink = observer

					testScheduler.schedule {
						for number in numbers {
							sink.sendNext(number)
						}
					}
				}
				
				var completed = false
				
				producer
					.take(numbers.count)
					.startWithCompleted { completed = true }
				
				expect(completed).to(beFalsy())
				testScheduler.run()
				expect(completed).to(beTruthy())
			}

			it("should interrupt when 0") {
				let numbers = [ 1, 2, 4, 4, 5 ]
				let testScheduler = TestScheduler()

				let producer: SignalProducer<Int, NoError> = SignalProducer { observer, _ in
					// workaround `Class declaration cannot close over value 'observer' defined in outer scope`
					let sink = observer

					testScheduler.schedule {
						for number in numbers {
							sink.sendNext(number)
						}
					}
				}

				var result: [Int] = []
				var interrupted = false

				producer
				.take(0)
				.start { event in
					switch event {
					case let .Next(number):
						result.append(number)
					case .Interrupted:
						interrupted = true
					default:
						break
					}
				}

				expect(interrupted).to(beTruthy())

				testScheduler.run()
				expect(result).to(beEmpty())
			}
		}

		describe("collect") {
			it("should collect all values") {
				let (original, sink) = SignalProducer<Int, NoError>.buffer()
				let producer = original.collect()
				let expectedResult = [ 1, 2, 3 ]

				var result: [Int]?

				producer.startWithNext { value in
					expect(result).to(beNil())
					result = value
				}

				for number in expectedResult {
					sink.sendNext(number)
				}

				expect(result).to(beNil())
				sink.sendCompleted()
				expect(result).to(equal(expectedResult))
			}

			it("should complete with an empty array if there are no values") {
				let (original, sink) = SignalProducer<Int, NoError>.buffer()
				let producer = original.collect()

				var result: [Int]?

				producer.startWithNext { result = $0 }

				expect(result).to(beNil())
				sink.sendCompleted()
				expect(result).to(equal([]))
			}

			it("should forward errors") {
				let (original, sink) = SignalProducer<Int, TestError>.buffer()
				let producer = original.collect()

				var error: TestError?

				producer.startWithError { error = $0 }

				expect(error).to(beNil())
				sink.sendError(.Default)
				expect(error).to(equal(TestError.Default))
			}
		}

		describe("takeUntil") {
			var producer: SignalProducer<Int, NoError>!
			var sink: Signal<Int, NoError>.Observer!
			var triggerSink: Signal<(), NoError>.Observer!

			var lastValue: Int? = nil
			var completed: Bool = false

			beforeEach {
				let (baseProducer, observer) = SignalProducer<Int, NoError>.buffer()
				let (triggerSignal, triggerObserver) = SignalProducer<(), NoError>.buffer()

				producer = baseProducer.takeUntil(triggerSignal)
				sink = observer
				triggerSink = triggerObserver

				lastValue = nil
				completed = false

				producer.start { event in
					switch event {
					case let .Next(value):
						lastValue = value
					case .Completed:
						completed = true
					default:
						break
					}
				}
			}

			it("should take values until the trigger fires") {
				expect(lastValue).to(beNil())

				sink.sendNext(1)
				expect(lastValue).to(equal(1))

				sink.sendNext(2)
				expect(lastValue).to(equal(2))

				expect(completed).to(beFalse())
				triggerSink.sendNext(())
				expect(completed).to(beTrue())
			}

			it("should complete if the trigger fires immediately") {
				expect(lastValue).to(beNil())
				expect(completed).to(beFalse())

				triggerSink.sendNext(())

				expect(completed).to(beTrue())
				expect(lastValue).to(beNil())
			}
		}

		describe("takeUntilReplacement") {
			var producer: SignalProducer<Int, NoError>!
			var sink: Signal<Int, NoError>.Observer!
			var replacementSink: Signal<Int, NoError>.Observer!

			var lastValue: Int? = nil
			var completed: Bool = false

			beforeEach {
				let (baseProducer, observer) = SignalProducer<Int, NoError>.buffer()
				let (replacementSignal, replacementObserver) = SignalProducer<Int, NoError>.buffer()

				producer = baseProducer.takeUntilReplacement(replacementSignal)
				sink = observer
				replacementSink = replacementObserver

				lastValue = nil
				completed = false

				producer.start { event in
					switch event {
					case let .Next(value):
						lastValue = value
					case .Completed:
						completed = true
					default:
						break
					}
				}
			}

			it("should take values from the original then the replacement") {
				expect(lastValue).to(beNil())
				expect(completed).to(beFalse())

				sink.sendNext(1)
				expect(lastValue).to(equal(1))

				sink.sendNext(2)
				expect(lastValue).to(equal(2))

				replacementSink.sendNext(3)

				expect(lastValue).to(equal(3))
				expect(completed).to(beFalse())

				sink.sendNext(4)

				expect(lastValue).to(equal(3))
				expect(completed).to(beFalse())

				replacementSink.sendNext(5)
				expect(lastValue).to(equal(5))

				expect(completed).to(beFalse())
				replacementSink.sendCompleted()
				expect(completed).to(beTrue())
			}
		}

		describe("takeWhile") {
			var producer: SignalProducer<Int, NoError>!
			var observer: Signal<Int, NoError>.Observer!

			beforeEach {
				let (baseProducer, sink) = SignalProducer<Int, NoError>.buffer()
				producer = baseProducer.takeWhile { $0 <= 4 }
				observer = sink
			}

			it("should take while the predicate is true") {
				var latestValue: Int!
				var completed = false

				producer.start { event in
					switch event {
					case let .Next(value):
						latestValue = value
					case .Completed:
						completed = true
					default:
						break
					}
				}

				for value in -1...4 {
					observer.sendNext(value)
					expect(latestValue).to(equal(value))
					expect(completed).to(beFalse())
				}

				observer.sendNext(5)
				expect(latestValue).to(equal(4))
				expect(completed).to(beTrue())
			}

			it("should complete if the predicate starts false") {
				var latestValue: Int?
				var completed = false

				producer.start { event in
					switch event {
					case let .Next(value):
						latestValue = value
					case .Completed:
						completed = true
					default:
						break
					}
				}

				observer.sendNext(5)
				expect(latestValue).to(beNil())
				expect(completed).to(beTrue())
			}
		}

		describe("observeOn") {
			it("should send events on the given scheduler") {
				let testScheduler = TestScheduler()
				let (producer, observer) = SignalProducer<Int, NoError>.buffer()

				var result: [Int] = []

				producer
					.observeOn(testScheduler)
					.startWithNext { result.append($0) }
				
				observer.sendNext(1)
				observer.sendNext(2)
				expect(result).to(beEmpty())
				
				testScheduler.run()
				expect(result).to(equal([ 1, 2 ]))
			}
		}

		describe("delay") {
			it("should send events on the given scheduler after the interval") {
				let testScheduler = TestScheduler()
				let producer: SignalProducer<Int, NoError> = SignalProducer { observer, _ in
					testScheduler.schedule {
						observer.sendNext(1)
					}
					testScheduler.scheduleAfter(5, action: {
						observer.sendNext(2)
						observer.sendCompleted()
					})
				}
				
				var result: [Int] = []
				var completed = false
				
				producer
					.delay(10, onScheduler: testScheduler)
					.start { event in
						switch event {
						case let .Next(number):
							result.append(number)
						case .Completed:
							completed = true
						default:
							break
						}
					}
				
				testScheduler.advanceByInterval(4) // send initial value
				expect(result).to(beEmpty())
				
				testScheduler.advanceByInterval(10) // send second value and receive first
				expect(result).to(equal([ 1 ]))
				expect(completed).to(beFalsy())
				
				testScheduler.advanceByInterval(10) // send second value and receive first
				expect(result).to(equal([ 1, 2 ]))
				expect(completed).to(beTruthy())
			}

			it("should schedule errors immediately") {
				let testScheduler = TestScheduler()
				let producer: SignalProducer<Int, TestError> = SignalProducer { observer, _ in
					// workaround `Class declaration cannot close over value 'observer' defined in outer scope`
					let sink = observer

					testScheduler.schedule {
						sink.sendError(TestError.Default)
					}
				}
				
				var errored = false
				
				producer
					.delay(10, onScheduler: testScheduler)
					.startWithError { _ in errored = true }
				
				testScheduler.advance()
				expect(errored).to(beTruthy())
			}
		}

		describe("throttle") {
			var scheduler: TestScheduler!
			var observer: Signal<Int, NoError>.Observer!
			var producer: SignalProducer<Int, NoError>!

			beforeEach {
				scheduler = TestScheduler()

				let (baseProducer, baseObserver) = SignalProducer<Int, NoError>.buffer()
				observer = baseObserver

				producer = baseProducer.throttle(1, onScheduler: scheduler)
			}

			it("should send values on the given scheduler at no less than the interval") {
				var values: [Int] = []
				producer.startWithNext { value in
					values.append(value)
				}

				expect(values).to(equal([]))

				observer.sendNext(0)
				expect(values).to(equal([]))

				scheduler.advance()
				expect(values).to(equal([ 0 ]))

				observer.sendNext(1)
				observer.sendNext(2)
				expect(values).to(equal([ 0 ]))

				scheduler.advanceByInterval(1.5)
				expect(values).to(equal([ 0, 2 ]))

				scheduler.advanceByInterval(3)
				expect(values).to(equal([ 0, 2 ]))

				observer.sendNext(3)
				expect(values).to(equal([ 0, 2 ]))

				scheduler.advance()
				expect(values).to(equal([ 0, 2, 3 ]))

				observer.sendNext(4)
				observer.sendNext(5)
				scheduler.advance()
				expect(values).to(equal([ 0, 2, 3 ]))

				scheduler.run()
				expect(values).to(equal([ 0, 2, 3, 5 ]))
			}

			it("should schedule completion immediately") {
				var values: [Int] = []
				var completed = false

				producer.start { event in
					switch event {
					case let .Next(value):
						values.append(value)
					case .Completed:
						completed = true
					default:
						break
					}
				}

				observer.sendNext(0)
				scheduler.advance()
				expect(values).to(equal([ 0 ]))

				observer.sendNext(1)
				observer.sendCompleted()
				expect(completed).to(beFalsy())

				scheduler.run()
				expect(values).to(equal([ 0 ]))
				expect(completed).to(beTruthy())
			}
		}

		describe("sampleOn") {
			var sampledProducer: SignalProducer<Int, NoError>!
			var observer: Signal<Int, NoError>.Observer!
			var samplerObserver: Signal<(), NoError>.Observer!
			
			beforeEach {
				let (producer, sink) = SignalProducer<Int, NoError>.buffer()
				let (sampler, samplesSink) = SignalProducer<(), NoError>.buffer()
				sampledProducer = producer.sampleOn(sampler)
				observer = sink
				samplerObserver = samplesSink
			}
			
			it("should forward the latest value when the sampler fires") {
				var result: [Int] = []
				sampledProducer.startWithNext { result.append($0) }
				
				observer.sendNext(1)
				observer.sendNext(2)
				samplerObserver.sendNext(())
				expect(result).to(equal([ 2 ]))
			}
			
			it("should do nothing if sampler fires before signal receives value") {
				var result: [Int] = []
				sampledProducer.startWithNext { result.append($0) }
				
				samplerObserver.sendNext(())
				expect(result).to(beEmpty())
			}
			
			it("should send lates value multiple times when sampler fires multiple times") {
				var result: [Int] = []
				sampledProducer.startWithNext { result.append($0) }
				
				observer.sendNext(1)
				samplerObserver.sendNext(())
				samplerObserver.sendNext(())
				expect(result).to(equal([ 1, 1 ]))
			}

			it("should complete when both inputs have completed") {
				var completed = false
				sampledProducer.startWithCompleted { completed = true }
				
				observer.sendCompleted()
				expect(completed).to(beFalsy())
				
				samplerObserver.sendCompleted()
				expect(completed).to(beTruthy())
			}
		}

		describe("combineLatestWith") {
			var combinedProducer: SignalProducer<(Int, Double), NoError>!
			var observer: Signal<Int, NoError>.Observer!
			var otherObserver: Signal<Double, NoError>.Observer!
			
			beforeEach {
				let (producer, sink) = SignalProducer<Int, NoError>.buffer()
				let (otherSignal, otherSink) = SignalProducer<Double, NoError>.buffer()
				combinedProducer = producer.combineLatestWith(otherSignal)
				observer = sink
				otherObserver = otherSink
			}
			
			it("should forward the latest values from both inputs") {
				var latest: (Int, Double)?
				combinedProducer.startWithNext { latest = $0 }
				
				observer.sendNext(1)
				expect(latest).to(beNil())
				
				// is there a better way to test tuples?
				otherObserver.sendNext(1.5)
				expect(latest?.0).to(equal(1))
				expect(latest?.1).to(equal(1.5))
				
				observer.sendNext(2)
				expect(latest?.0).to(equal(2))
				expect(latest?.1).to(equal(1.5))
			}

			it("should complete when both inputs have completed") {
				var completed = false
				combinedProducer.startWithCompleted { completed = true }
				
				observer.sendCompleted()
				expect(completed).to(beFalsy())
				
				otherObserver.sendCompleted()
				expect(completed).to(beTruthy())
			}
		}

		describe("zipWith") {
			var leftSink: Signal<Int, NoError>.Observer!
			var rightSink: Signal<String, NoError>.Observer!
			var zipped: SignalProducer<(Int, String), NoError>!

			beforeEach {
				let (leftProducer, leftObserver) = SignalProducer<Int, NoError>.buffer()
				let (rightProducer, rightObserver) = SignalProducer<String, NoError>.buffer()

				leftSink = leftObserver
				rightSink = rightObserver
				zipped = leftProducer.zipWith(rightProducer)
			}

			it("should combine pairs") {
				var result: [String] = []
				zipped.startWithNext { (left, right) in result.append("\(left)\(right)") }

				leftSink.sendNext(1)
				leftSink.sendNext(2)
				expect(result).to(equal([]))

				rightSink.sendNext("foo")
				expect(result).to(equal([ "1foo" ]))

				leftSink.sendNext(3)
				rightSink.sendNext("bar")
				expect(result).to(equal([ "1foo", "2bar" ]))

				rightSink.sendNext("buzz")
				expect(result).to(equal([ "1foo", "2bar", "3buzz" ]))

				rightSink.sendNext("fuzz")
				expect(result).to(equal([ "1foo", "2bar", "3buzz" ]))

				leftSink.sendNext(4)
				expect(result).to(equal([ "1foo", "2bar", "3buzz", "4fuzz" ]))
			}

			it("should complete when the shorter signal has completed") {
				var result: [String] = []
				var completed = false

				zipped.start { event in
					switch event {
					case let .Next(left, right):
						result.append("\(left)\(right)")
					case .Completed:
						completed = true
					default:
						break
					}
				}

				expect(completed).to(beFalsy())

				leftSink.sendNext(0)
				leftSink.sendCompleted()
				expect(completed).to(beFalsy())
				expect(result).to(equal([]))

				rightSink.sendNext("foo")
				expect(completed).to(beTruthy())
				expect(result).to(equal([ "0foo" ]))
			}
		}

		describe("materialize") {
			it("should reify events from the signal") {
				let (producer, observer) = SignalProducer<Int, TestError>.buffer()
				var latestEvent: Event<Int, TestError>?
				producer
					.materialize()
					.startWithNext { latestEvent = $0 }
				
				observer.sendNext(2)
				
				expect(latestEvent).toNot(beNil())
				if let latestEvent = latestEvent {
					switch latestEvent {
					case let .Next(value):
						expect(value).to(equal(2))
					default:
						fail()
					}
				}
				
				observer.sendError(TestError.Default)
				if let latestEvent = latestEvent {
					switch latestEvent {
					case .Error(_):
						()
					default:
						fail()
					}
				}
			}
		}

		describe("dematerialize") {
			typealias IntEvent = Event<Int, TestError>
			var sink: Signal<IntEvent, NoError>.Observer!
			var dematerialized: SignalProducer<Int, TestError>!
			
			beforeEach {
				let (producer, observer) = SignalProducer<IntEvent, NoError>.buffer()
				sink = observer
				dematerialized = producer.dematerialize()
			}
			
			it("should send values for Next events") {
				var result: [Int] = []
				dematerialized.startWithNext { result.append($0) }
				
				expect(result).to(beEmpty())
				
				sink.sendNext(.Next(2))
				expect(result).to(equal([ 2 ]))
				
				sink.sendNext(.Next(4))
				expect(result).to(equal([ 2, 4 ]))
			}

			it("should error out for Error events") {
				var errored = false
				dematerialized.startWithError { _ in errored = true }
				
				expect(errored).to(beFalsy())
				
				sink.sendNext(.Error(TestError.Default))
				expect(errored).to(beTruthy())
			}

			it("should complete early for Completed events") {
				var completed = false
				dematerialized.startWithCompleted { completed = true }
				
				expect(completed).to(beFalsy())
				sink.sendNext(IntEvent.Completed)
				expect(completed).to(beTruthy())
			}
		}

		describe("takeLast") {
			var sink: Signal<Int, TestError>.Observer!
			var lastThree: SignalProducer<Int, TestError>!
				
			beforeEach {
				let (producer, observer) = SignalProducer<Int, TestError>.buffer()
				sink = observer
				lastThree = producer.takeLast(3)
			}
			
			it("should send the last N values upon completion") {
				var result: [Int] = []
				lastThree.startWithNext { result.append($0) }
				
				sink.sendNext(1)
				sink.sendNext(2)
				sink.sendNext(3)
				sink.sendNext(4)
				expect(result).to(beEmpty())
				
				sink.sendCompleted()
				expect(result).to(equal([ 2, 3, 4 ]))
			}

			it("should send less than N values if not enough were received") {
				var result: [Int] = []
				lastThree.startWithNext { result.append($0) }
				
				sink.sendNext(1)
				sink.sendNext(2)
				sink.sendCompleted()
				expect(result).to(equal([ 1, 2 ]))
			}
			
			it("should send nothing when errors") {
				var result: [Int] = []
				var errored = false
				lastThree.start { event in
					switch event {
					case let .Next(value):
						result.append(value)
					case .Error(_):
						errored = true
					default:
						break
					}
				}
				
				sink.sendNext(1)
				sink.sendNext(2)
				sink.sendNext(3)
				expect(errored).to(beFalsy())
				
				sink.sendError(TestError.Default)
				expect(errored).to(beTruthy())
				expect(result).to(beEmpty())
			}
		}

		describe("timeoutWithError") {
			var testScheduler: TestScheduler!
			var producer: SignalProducer<Int, TestError>!
			var sink: Signal<Int, TestError>.Observer!

			beforeEach {
				testScheduler = TestScheduler()
				let (baseProducer, observer) = SignalProducer<Int, TestError>.buffer()
				producer = baseProducer.timeoutWithError(TestError.Default, afterInterval: 2, onScheduler: testScheduler)
				sink = observer
			}

			it("should complete if within the interval") {
				var completed = false
				var errored = false
				producer.start { event in
					switch event {
					case .Completed:
						completed = true
					case .Error(_):
						errored = true
					default:
						break
					}
				}

				testScheduler.scheduleAfter(1) {
					sink.sendCompleted()
				}

				expect(completed).to(beFalsy())
				expect(errored).to(beFalsy())

				testScheduler.run()
				expect(completed).to(beTruthy())
				expect(errored).to(beFalsy())
			}

			it("should error if not completed before the interval has elapsed") {
				var completed = false
				var errored = false
				producer.start { event in
					switch event {
					case .Completed:
						completed = true
					case .Error(_):
						errored = true
					default:
						break
					}
				}

				testScheduler.scheduleAfter(3) {
					sink.sendCompleted()
				}

				expect(completed).to(beFalsy())
				expect(errored).to(beFalsy())

				testScheduler.run()
				expect(completed).to(beFalsy())
				expect(errored).to(beTruthy())
			}
		}

		describe("attempt") {
			it("should forward original values upon success") {
				let (baseProducer, sink) = SignalProducer<Int, TestError>.buffer()
				let producer = baseProducer.attempt { _ in
					return .Success()
				}
				
				var current: Int?
				producer.startWithNext { value in
					current = value
				}
				
				for value in 1...5 {
					sink.sendNext(value)
					expect(current).to(equal(value))
				}
			}
			
			it("should error if an attempt fails") {
				let (baseProducer, sink) = SignalProducer<Int, TestError>.buffer()
				let producer = baseProducer.attempt { _ in
					return .Failure(.Default)
				}
				
				var error: TestError?
				producer.startWithError { err in
					error = err
				}
				
				sink.sendNext(42)
				expect(error).to(equal(TestError.Default))
			}
		}
		
		describe("attemptMap") {
			it("should forward mapped values upon success") {
				let (baseProducer, sink) = SignalProducer<Int, TestError>.buffer()
				let producer = baseProducer.attemptMap { num -> Result<Bool, TestError> in
					return .Success(num % 2 == 0)
				}
				
				var even: Bool?
				producer.startWithNext { value in
					even = value
				}
				
				sink.sendNext(1)
				expect(even).to(equal(false))
				
				sink.sendNext(2)
				expect(even).to(equal(true))
			}
			
			it("should error if a mapping fails") {
				let (baseProducer, sink) = SignalProducer<Int, TestError>.buffer()
				let producer = baseProducer.attemptMap { _ -> Result<Bool, TestError> in
					return .Failure(.Default)
				}
				
				var error: TestError?
				producer.startWithError { err in
					error = err
				}
				
				sink.sendNext(42)
				expect(error).to(equal(TestError.Default))
			}
		}
		
		describe("combinePrevious") {
			var sink: Signal<Int, NoError>.Observer!
			let initialValue: Int = 0
			var latestValues: (Int, Int)?
			
			beforeEach {
				latestValues = nil
				
				let (signal, baseSink) = SignalProducer<Int, NoError>.buffer()
				sink = baseSink
				signal.combinePrevious(initialValue).startWithNext { latestValues = $0 }
			}
			
			it("should forward the latest value with previous value") {
				expect(latestValues).to(beNil())
				
				sink.sendNext(1)
				expect(latestValues?.0).to(equal(initialValue))
				expect(latestValues?.1).to(equal(1))
				
				sink.sendNext(2)
				expect(latestValues?.0).to(equal(1))
				expect(latestValues?.1).to(equal(2))
			}
		}
	}
}
