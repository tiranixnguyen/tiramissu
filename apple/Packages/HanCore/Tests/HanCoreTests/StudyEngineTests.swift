import Testing

@testable import HanCore

@Suite("StudyEngine")
struct StudyEngineTests {
    @Suite("dựng dữ liệu (buildStudyCatalog)")
    struct Catalog {
        @Test func sapTheoPositionKhongTheoThuTuTrongJson() {
            var deck = contentDeck("d1", threeWords)
            deck.cards.reverse()
            let c = contentOf([deck]).buildStudyCatalog()
            #expect(c.decks.first?.words.map(\.back) == ["학생", "선생님", "학교"])
        }

        @Test func gomCoTheoIdThe() {
            let c = contentOf([
                contentDeck("d1", threeWords, marked: [1], hanja: [0, 2], passage: [2])
            ]).buildStudyCatalog()
            #expect(c.markedIds == ["d1-1"])
            #expect(c.hanjaIds == ["d1-0", "d1-2"])
            #expect(c.passageIds == ["d1-2"])
        }

        @Test func sapNhomVaBoTheoPosition() {
            let content = contentOf(
                [
                    contentDeck("b", threeWords, position: 1),
                    contentDeck("a", threeWords, position: 0),
                ],
                groups: [
                    ContentGroup(id: "g2", name: "Sep2", position: 1),
                    ContentGroup(id: "g1", name: "Sep1", position: 0),
                ])
            let c = content.buildStudyCatalog()
            #expect(c.decks.map(\.id) == ["a", "b"])
            #expect(c.vocabGroups.map(\.id) == ["g1", "g2"])
        }
    }

    @Suite("chấm bài")
    struct Grading {
        @Test func chapNhanDapAnPhuVaBoQuaKhoangTrangThua() {
            let e = buildEngine([RawWord(front: "cảm ơn", back: "감사합니다", altAnswers: ["고맙습니다"])])
            #expect(e.checkAnswer("  고맙습니다  "))
            #expect(e.correctCount == 1)
            #expect(e.attemptedCount == 1)
        }

        @Test func dapAnRongKhongTinhLaMotLanTraLoi() {
            let e = buildEngine()
            #expect(!e.checkAnswer("   "))
            #expect(e.attemptedCount == 0)
            #expect(!e.answered)
        }

        @Test func theDaTraLoiThiKhongChamLai() {
            let e = buildEngine()
            e.checkAnswer("sai bét")
            let attempts = e.attemptedCount
            e.checkAnswer(e.currentWord!.back)
            #expect(e.attemptedCount == attempts)
        }
    }

    @Suite("lịch Leitner")
    struct Leitner {
        @Test func dungBaLanLienTiepThiThanhThuoc() {
            let e = buildEngine([RawWord(front: "học sinh", back: "학생")])
            for _ in 0..<StudyEngine.masteryStreak {
                answerCurrentCorrectly(e)
                e.nextCard()
            }
            #expect(e.masteredCount == 1)
            #expect(e.isCompleted)
        }

        @Test func traLoiSaiDatLaiStreakVaBoxVe0() {
            let e = buildEngine([RawWord(front: "học sinh", back: "학생"), RawWord(front: "trường học", back: "학교")])
            answerCurrentCorrectly(e)
            #expect(e.currentProgress?.streak == 1)
            #expect(e.currentProgress?.box == 1)

            e.nextCard()
            let target = e.currentWord!.back
            e.checkAnswer("đáp án sai")
            #expect(e.outcome == .wrong)
            while e.currentWord!.back != target { e.nextCard() }
            #expect(e.currentProgress?.streak == 0)
            #expect(e.currentProgress?.box == 0)
        }

        @Test func theSaiQuayLaiSauDungHaiThe() {
            // 5 thẻ → sau khi lấy 1 ra còn 4 trong hàng đợi; sai → chèn ở vị trí 2.
            let words = (0..<5).map { RawWord(front: "v\($0)", back: "k\($0)") }
            let e = buildEngine(words)
            let first = e.currentIndex!
            e.checkAnswer("sai")
            for _ in 0..<2 {
                e.nextCard()
                #expect(e.currentIndex != first)
            }
            e.nextCard()
            #expect(e.currentIndex == first)
        }

        @Test func theSaiDuocChenLaiVaoHangDoi() {
            let e = buildEngine()
            let before = e.remainingInRound
            e.checkAnswer("đáp án sai")
            #expect(e.remainingInRound == before + 1)
        }

        @Test func moiLuotHoiMoiTangCardSerialKeCaHoiLaiCungThe() {
            let e = buildEngine([RawWord(front: "học sinh", back: "학생")])
            let first = e.cardSerial
            e.checkAnswer("sai")
            e.nextCard()
            #expect(e.currentWord?.back == "학생")
            #expect(e.cardSerial > first)
        }

        @Test func snapshotPhanAnhTrangThai() {
            let e = buildEngine()
            e.checkAnswer("sai")
            let s = e.snapshot()
            #expect(s.outcome == .wrong)
            #expect(s.canOverride)
            #expect(s.attemptedCount == 1)
            #expect(s.cardSerial == e.cardSerial)
        }
    }
    @Suite("tự xác nhận đúng")
    struct Override {
        @Test func hoanTacNhanhSaiVaApLaiLichTheoHuongDung() {
            let e = buildEngine()
            answerCurrentCorrectly(e)  // box 0→1, streak 0→1
            e.nextCard()
            while e.currentProgress?.streak != 1 { e.nextCard() }

            e.checkAnswer("gõ nhầm chính tả")
            #expect(e.canOverride)
            #expect(!e.overridden)

            e.overrideAsCorrect()
            #expect(e.outcome == .correct)
            #expect(!e.canOverride)
            #expect(e.overridden)

            e.nextCard()
            #expect(!e.overridden)
            // Streak nối tiếp từ 1 chứ không khởi động lại từ 0.
            #expect(e.currentProgress?.streak == 2)
            #expect(e.currentProgress?.box == 2)
        }

        @Test func khongChoTuXacNhanSauXemDapAn() {
            let e = buildEngine()
            e.revealAnswer()
            #expect(e.outcome == .wrong)
            #expect(!e.canOverride)
            e.overrideAsCorrect()
            #expect(e.correctCount == 0)
        }

        @Test func daThuocLamThuocNgayVaGiuDapAn() {
            let e = buildEngine()
            e.markKnown()
            #expect(e.outcome == .known)
            #expect(e.masteredCount == 1)
            #expect(e.currentProgress?.mastered == true)
        }
    }
    @Suite("thẻ tự chấm")
    struct SelfGraded {
        static let selfGraded = [
            RawWord(front: "học sinh", back: "학생", typeAnswer: false),
            RawWord(front: "giáo viên", back: "선생님", typeAnswer: false),
            RawWord(front: "trường học", back: "학교", typeAnswer: false),
        ]

        @Test func latChuaPhaiLaTraLoi() {
            let e = buildEngine(Self.selfGraded)
            let remaining = e.remainingInRound
            e.flipCard()
            #expect(e.flipped)
            #expect(!e.answered)
            #expect(e.attemptedCount == 0)
            #expect(e.remainingInRound == remaining)
            #expect(e.currentProgress?.streak == 0)
        }

        @Test func chuaLatThiKhongTuChamDuoc() {
            let e = buildEngine(Self.selfGraded)
            e.gradeSelf(remembered: true)
            #expect(!e.answered)
            #expect(e.attemptedCount == 0)
        }

        @Test func nhoDiNhanhDungChuaNhoDiNhanhSai() {
            let e = buildEngine(Self.selfGraded)
            e.flipCard()
            e.gradeSelf(remembered: true)
            #expect(e.outcome == .correct)
            #expect(e.currentProgress?.streak == 1)
            #expect(e.currentProgress?.box == 1)
            #expect(!e.canOverride)

            e.nextCard()
            #expect(!e.flipped)
            e.flipCard()
            e.gradeSelf(remembered: false)
            #expect(e.outcome == .wrong)
            #expect(e.currentProgress?.box == 0)
            #expect(!e.canOverride)
            #expect(e.correctCount == 1)
            #expect(e.attemptedCount == 2)
        }

        @Test func chamHaiLanChiTinhLanDau() {
            let e = buildEngine(Self.selfGraded)
            e.flipCard()
            e.gradeSelf(remembered: false)
            e.gradeSelf(remembered: true)
            #expect(e.attemptedCount == 1)
            #expect(e.correctCount == 0)
        }

        @Test func nhoBaLanLienTiepThiThuocHetBo() {
            let e = buildEngine([Self.selfGraded[0]])
            for _ in 0..<StudyEngine.masteryStreak {
                e.flipCard()
                e.gradeSelf(remembered: true)
                e.nextCard()
            }
            #expect(e.isCompleted)
            #expect(e.masteredCount == 1)
        }

        @Test func theTuChamKhongNhanGoDapAnHayXemDapAn() {
            let e = buildEngine(Self.selfGraded)
            #expect(!e.checkAnswer(e.currentWord!.back))
            e.revealAnswer()
            #expect(!e.answered)
            #expect(e.attemptedCount == 0)
        }

        @Test func theGoDapAnKhongLatHayTuChamDuoc() {
            let e = buildEngine()
            e.flipCard()
            #expect(!e.flipped)
            e.gradeSelf(remembered: true)
            #expect(!e.answered)
        }

        @Test func daThuocVanDungDuocSauKhiLat() {
            let e = buildEngine(Self.selfGraded)
            e.flipCard()
            e.markKnown()
            #expect(e.outcome == .known)
            #expect(e.masteredCount == 1)
        }
    }
    @Suite("mỗi thẻ độc lập (đã bỏ thẻ ngữ cảnh)")
    struct Independent {
        @Test func thuocMotTheKhongLamThuocTheKhac() {
            let e = buildEngine()
            e.markKnown()
            #expect(e.masteredCount == 1)
            e.nextCard()
            answerCurrentCorrectly(e)
            #expect(e.masteredCount == 1)
        }

        @Test func boAoDungChungTheVoiBoGoc() {
            let c = contentOf([contentDeck("d1", threeWords, marked: [1])]).buildStudyCatalog()
            let e = StudyEngine(
                decks: c.decks, vocabGroups: c.vocabGroups, markedIds: c.markedIds,
                random: SeededGenerator(seed: 1))
            e.bootstrap()
            e.switchDeck(markedDeckId)
            #expect(e.currentWord == c.decks[0].words[1])
        }
    }

    @Suite("đánh dấu và deck ảo")
    struct Flags {
        @Test func toggleTraGiaTriMoi() {
            let e = buildEngine()
            #expect(e.markedCount == 0)
            #expect(e.toggleMark() == true)
            #expect(e.currentIsMarked)
            #expect(e.markedCount == 1)
            #expect(e.toggleMark() == false)
            #expect(!e.currentIsMarked)
            #expect(e.markedCount == 0)
        }

        @Test func coHanHanTachBietVoiCoKhoNho() {
            let e = buildEngine()
            e.toggleHanja()
            #expect(e.currentIsHanja)
            #expect(!e.currentIsMarked)
            #expect(e.hanjaCount == 1)
            #expect(e.markedCount == 0)
        }

        @Test func coDoanVanTachBietVoiMarkHanja() {
            let e = buildEngine()
            #expect(e.togglePassage() == true)
            #expect(e.currentIsPassage)
            #expect(!e.currentIsMarked)
            #expect(!e.currentIsHanja)
            #expect(e.passageCount == 1)
            #expect(e.togglePassage() == false)
            #expect(e.passageCount == 0)
        }

        @Test func deckSachChiGomTheGanCoVaLaDeckAo() {
            let e = engineFor(contentOf([contentDeck("d1", threeWords, hanja: [1], passage: [0, 2])]))
            e.switchDeck(passageDeckId)
            #expect(isVirtualDeckId(passageDeckId))
            #expect(e.currentDeck?.isVirtual == true)
            #expect(e.currentDeck?.name == "📖 Đoạn văn ngắn")
            #expect(e.currentDeck?.words.map(\.id) == ["d1-0", "d1-2"])
        }

        @Test func boCoPassageTrongDeckThiTheRoiKhiSangTheTiep() {
            let e = engineFor(contentOf([contentDeck("d1", threeWords, passage: [0, 2])]))
            e.switchDeck(passageDeckId)
            e.togglePassage()
            #expect(e.totalCount == 2)
            e.revealAnswer()
            e.nextCard()
            #expect(e.totalCount == 1)
        }

        @Test func coCoSanTuNoiDungDuocNapTheoIdThe() {
            let e = engineFor(contentOf([contentDeck("d1", threeWords, marked: [2])]))
            #expect(e.markedCount == 1)
            e.switchDeck(markedDeckId)
            #expect(e.currentWord?.back == "학교")
            #expect(e.currentWord?.id == "d1-2")
            #expect(e.currentIsMarked)
        }

        @Test func chuyenSangDeckSaoHocDungTuDaDanhDau() {
            let e = buildEngine()
            let marked = e.currentWord!.back
            e.toggleMark()
            e.switchDeck(markedDeckId)
            #expect(e.currentDeckId == markedDeckId)
            #expect(e.totalCount == 1)
            #expect(e.currentWord?.back == marked)
        }

        @Test func deckSaoChiGomTuCuaNhomDangMo() {
            let e = engineFor(
                contentOf(
                    [
                        contentDeck("d1", threeWords, marked: [0]),
                        contentDeck("d2", threeWords, groupId: "g2", marked: [0, 1]),
                    ],
                    groups: [
                        ContentGroup(id: "g1", name: "Sep1", position: 0),
                        ContentGroup(id: "g2", name: "Sep2", position: 1),
                    ]))
            #expect(e.markedCount == 1)
            e.switchVocabGroup("g2")
            #expect(e.markedCount == 2)
        }

        @Test func boSaoTrongDeckSaoTheOLaiRoiKhongQuayLai() {
            let e = engineFor(contentOf([contentDeck("d1", threeWords, marked: [0, 1])]))
            e.switchDeck(markedDeckId)
            let dropped = e.currentWord!.id

            #expect(e.toggleMark() == false)
            #expect(e.currentWord?.id == dropped)
            #expect(e.totalCount == 2)

            e.revealAnswer()
            e.nextCard()
            #expect(e.totalCount == 1)
            #expect(e.currentWord?.id != dropped)

            for _ in 0..<StudyEngine.masteryStreak {
                #expect(e.currentWord?.id != dropped)
                answerCurrentCorrectly(e)
                e.nextCard()
            }
            #expect(e.isCompleted)
            #expect(e.currentWord == nil)
        }

        @Test func boSaoRoiBatLaiTruocKhiSangTheTiepThiTheVanOLai() {
            let e = engineFor(contentOf([contentDeck("d1", threeWords, marked: [0, 1])]))
            e.switchDeck(markedDeckId)
            e.toggleMark()
            e.toggleMark()
            e.revealAnswer()
            e.nextCard()
            #expect(e.totalCount == 2)
        }

        @Test func boCoTheCuoiTrongDeckHanThiDeckRongKhongCrash() {
            let e = engineFor(contentOf([contentDeck("d1", threeWords, hanja: [2])]))
            e.switchDeck(hanjaDeckId)
            e.toggleHanja()
            e.markKnown()
            e.nextCard()
            #expect(e.totalCount == 0)
            #expect(e.currentWord == nil)
        }

        @Test func deckNgauNhienRut20TheTrongNhomVaDungSeed() {
            let words = (0..<30).map { RawWord(front: "v\($0)", back: "k\($0)") }
            let a = engineFor(contentOf([contentDeck("d1", words)]), seed: 7)
            let b = engineFor(contentOf([contentDeck("d1", words)]), seed: 7)
            a.switchDeck(randomDeckId)
            b.switchDeck(randomDeckId)
            #expect(a.totalCount == 20)
            #expect(a.currentDeck?.words == b.currentDeck?.words)
            #expect(a.currentDeck?.isVirtual == true)
        }
    }
    @Suite("mỗi lần vào bộ là một lượt mới")
    struct FreshRun {
        @Test func quayLaiBoVuaHocDoThiBatDauLaiTuDau() {
            let e = buildEngine()
            answerCurrentCorrectly(e)
            e.nextCard()
            #expect(e.attemptedCount == 1)

            e.toggleMark()
            e.switchDeck(markedDeckId)
            e.switchDeck("d1")

            #expect(e.attemptedCount == 0)
            #expect(e.masteredCount == 0)
            #expect(e.remainingInRound == e.totalCount)
        }

        @Test func hocLaiTuDauXoaTienTrinhLuotNay() {
            let e = buildEngine([RawWord(front: "học sinh", back: "학생")])
            for _ in 0..<StudyEngine.masteryStreak {
                answerCurrentCorrectly(e)
                e.nextCard()
            }
            #expect(e.isCompleted)

            e.restartCurrentDeck()
            #expect(!e.isCompleted)
            #expect(e.attemptedCount == 0)
        }

        @Test func hocLaiBoNgauNhienRutBoMoi() {
            let words = (0..<40).map { RawWord(front: "v\($0)", back: "k\($0)") }
            let e = engineFor(contentOf([contentDeck("d1", words)]))
            e.switchDeck(randomDeckId)
            let first = e.currentDeck?.words
            e.restartCurrentDeck()
            #expect(e.currentDeckId == randomDeckId)
            #expect(e.totalCount == 20)
            #expect(e.currentDeck?.words != first)
        }
    }
    @Suite("nội dung thay đổi giữa lượt (replaceContent)")
    struct Replace {
        @Test func suaTheGiuLuotHocTheDangHoiHienNoiDungMoi() {
            let content = contentOf([contentDeck("d1", threeWords)])
            let e = engineFor(content)
            answerCurrentCorrectly(e)
            let id = e.currentWord!.id
            let serial = e.cardSerial

            let changed = replaceWith(e, content.updateCard(id) { $0.front = "nghĩa mới" })

            #expect(!changed)
            #expect(e.currentWord?.id == id)
            #expect(e.currentWord?.front == "nghĩa mới")
            #expect(e.cardSerial == serial)
            #expect(e.answered)
            #expect(e.currentProgress?.streak == 1)
            #expect(e.attemptedCount == 1)
        }

        @Test func xoaTheDangHoiChuyenSangTheKhacKhongQuayLai() {
            let content = contentOf([contentDeck("d1", threeWords)])
            let e = engineFor(content)
            let gone = e.currentWord!.id

            let changed = replaceWith(e, content.removeCard(gone))

            #expect(changed)
            #expect(e.totalCount == 2)
            var seen = Set<String>()
            for _ in 0..<6 {
                seen.insert(e.currentWord!.id)
                e.revealAnswer()
                e.nextCard()
            }
            #expect(!seen.contains(gone))
        }

        @Test func xoaMotTheChiRoiDungTheDo() {
            let content = contentOf([contentDeck("d1", threeWords)])
            let e = engineFor(content)
            #expect(e.totalCount == 3)
            replaceWith(e, content.removeCard("d1-0"))
            #expect(e.totalCount == 2)
        }

        @Test func themTuVaoBoDangHocTuMoiDuocHoi() {
            let e = engineFor(contentOf([contentDeck("d1", Array(threeWords.prefix(2)))]))
            replaceWith(e, contentOf([contentDeck("d1", threeWords)]))
            #expect(e.totalCount == 3)
            var seen = Set<String>()
            for _ in 0..<10 {
                seen.insert(e.currentWord!.back)
                e.revealAnswer()
                e.nextCard()
            }
            #expect(seen.contains("학교"))
        }

        @Test func theDaThuocVanThuocSauKhiTaiLai() {
            let content = contentOf([contentDeck("d1", threeWords)])
            let e = engineFor(content)
            e.markKnown()
            #expect(e.masteredCount == 1)
            replaceWith(e, content)
            #expect(e.masteredCount == 1)
        }

        @Test func boDangHocBiXoaThiMoBoDauTien() {
            let e = engineFor(
                contentOf([contentDeck("d1", threeWords), contentDeck("d2", threeWords, position: 1)]))
            e.switchDeck("d2")
            let changed = replaceWith(e, contentOf([contentDeck("d1", threeWords)]))
            #expect(changed)
            #expect(e.currentDeckId == "d1")
        }

        @Test func boSaoTrenMayKhacKhiDangHocDeckSaoTheRoiKhoiLuot() {
            let content = contentOf([contentDeck("d1", threeWords, marked: [0, 1])])
            let e = engineFor(content)
            e.switchDeck(markedDeckId)
            #expect(e.totalCount == 2)

            replaceWith(e, content.updateCard("d1-0") { $0.marked = false })
            #expect(e.currentDeckId == markedDeckId)
            #expect(e.totalCount == 1)
            #expect(e.currentWord?.id == "d1-1")
        }

        @Test func taiLaiGiuaLuotDeckPassageDungLaiTheoCoMoi() {
            let e = engineFor(contentOf([contentDeck("d1", threeWords, passage: [0])]))
            e.switchDeck(passageDeckId)
            replaceWith(e, contentOf([contentDeck("d1", threeWords, passage: [0, 1])]))
            #expect(e.currentDeckId == passageDeckId)
            #expect(e.totalCount == 2)
        }

        @Test func taiLaiGiuaLucDaLatVanGiuTrangThaiLat() {
            let words = [
                RawWord(front: "học sinh", back: "학생", typeAnswer: false),
                RawWord(front: "giáo viên", back: "선생님", typeAnswer: false),
                RawWord(front: "trường học", back: "학교", typeAnswer: false),
            ]
            let content = contentOf([contentDeck("d1", words)])
            let e = engineFor(content)
            e.flipCard()
            let id = e.currentWord!.id
            replaceWith(e, content.updateCard(id) { $0.front = "nghĩa mới" })
            #expect(e.currentWord?.front == "nghĩa mới")
            #expect(e.flipped)
        }

        @Test func boAoGiuNguyenKieuTheCuaTheGoc() {
            let words = [RawWord(front: "học sinh", back: "학생", typeAnswer: false)]
            let e = engineFor(contentOf([contentDeck("d1", words, marked: [0])]))
            e.switchDeck(markedDeckId)
            #expect(e.currentWord?.typeAnswer == false)
        }
    }
}

/// Dựng engine từ nội dung (có cờ), đã `bootstrap` với seed cố định.
func engineFor(_ content: ContentSnapshot, seed: UInt64 = 1) -> StudyEngine {
    let c = content.buildStudyCatalog()
    let e = StudyEngine(
        decks: c.decks, vocabGroups: c.vocabGroups, markedIds: c.markedIds, hanjaIds: c.hanjaIds,
        passageIds: c.passageIds, random: SeededGenerator(seed: seed))
    e.bootstrap()
    return e
}

/// Nạp nội dung mới vào engine như khi tải lại từ server.
@discardableResult
func replaceWith(_ e: StudyEngine, _ content: ContentSnapshot) -> Bool {
    e.replaceContent(content.buildStudyCatalog())
}

/// Dựng engine một nhóm, một bộ `d1`, đã `bootstrap` với seed cố định.
func buildEngine(_ words: [RawWord] = threeWords, seed: UInt64 = 1) -> StudyEngine {
    let c = contentOf([contentDeck("d1", words)]).buildStudyCatalog()
    let e = StudyEngine(decks: c.decks, vocabGroups: c.vocabGroups, random: SeededGenerator(seed: seed))
    e.bootstrap()
    return e
}

/// Trả lời đúng thẻ đang hiển thị, dù nó là thẻ nào.
func answerCurrentCorrectly(_ e: StudyEngine) {
    #expect(e.checkAnswer(e.currentWord!.back))
}
