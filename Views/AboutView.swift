import SwiftUI

struct AboutView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                // Header
                VStack(alignment: .leading, spacing: 20) {
                    Image("AppLogoPdf")
                    Text("ABOUT")
                        .font(.system(size: 28, weight: .semibold))
                        .foregroundColor(Color(red: 0.6, green: 0.4, blue: 1.0))
                    
                }
                .padding(.top, 16)
                
                // Introduction
                Text("We have been learning languages for as long as we have spoken them. Through thousands of years of trial and error, language-learning methods have shifted and evolved. One truth has stood the test of time: those who immerse themselves in a language become more native-like than those who don't.")
                    .font(.system(size: 16))
                    .foregroundColor(.white.opacity(0.85))
                    .lineSpacing(6)
                
                // Why Babies Are the Best Language Learners
                VStack(alignment: .leading, spacing: 12) {
                    Text("Why Babies Are the Best Language Learners")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundColor(.white)
                    
                    Text("Who among us learns languages the best? The answer is babies. Babies master languages better than anyone, with nearly 100% achieving native-like fluency in their first language. They're also the most immersed, surrounded by speech from day one. There's no \"critical period\" as often claimed in language-acquisition circles, just a gradual decline in the likelihood of native-like fluency as we age. Yet, some learners start well past childhood and still sound indistinguishable from native speakers. Babies learn by listening and copying, and that's exactly what we should do too.")
                        .font(.system(size: 16))
                        .foregroundColor(.white.opacity(0.85))
                        .lineSpacing(6)
                }
                
                // Your Journey, Your Way
                VStack(alignment: .leading, spacing: 12) {
                    Text("Your Journey, Your Way")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundColor(.white)
                    
                    Text("There is no one method for learning languages. Some people love feeling smart and memorizing a list of words and translations. Others like to speak from day one to feel like they are doing something. The approach depends on your goals and your ideal of your future self. If you want to feel accomplished and build vocabulary fast, a game-based app like Duolingo might be what you need. If you thrive in structured settings with others, maybe you should take a class. If you want to acquire a language the natural, fun way, LiNGUiD is for you. The more time you spend scrolling through our immersive videos, the more language you acquire. Behind the scenes, our science-backed formula tailors content to your level, so you improve without even trying.")
                        .font(.system(size: 16))
                        .foregroundColor(.white.opacity(0.85))
                        .lineSpacing(6)
                    
                    Text("Want to actively practice? Our next-generation vocabulary system lets you save words from videos, see their definitions, and add them to your word bank for flashcard practice, all in context for better retention. Whether you're a novice building confidence or an advanced learner refining your skills, LiNGUiD makes learning feel natural and fun.")
                        .font(.system(size: 16))
                        .foregroundColor(.white.opacity(0.85))
                        .lineSpacing(6)
                }
                
                // Why LiNGUiD Stands Out
                VStack(alignment: .leading, spacing: 12) {
                    Text("Why LiNGUiD Stands Out")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundColor(.white)
                    
                    Text("At LiNGUiD, we make language learning as effortless and accessible as possible, using proven methods to transform you into a natural-sounding communicator. You'll leave people wondering, \"Where did you learn?\" and \"How did you get so fluent so fast?\"")
                        .font(.system(size: 16))
                        .foregroundColor(.white.opacity(0.85))
                        .lineSpacing(6)
                    
                    Text("Let's talk about why other methods fall short:")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white)
                        .padding(.top, 8)
                }
                
                // The Classroom Approach
                VStack(alignment: .leading, spacing: 10) {
                    Text("The Classroom Approach")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(Color(red: 255/256, green: 76/256, blue: 76/256))
                    
                    Text("It's the most common method worldwide, yet it fails so many. Most of you took a language in school, roughly 150 hours of class time, plus homework, nearing 200 hours. How many feel confident having a conversation in that language? Likely not many. I took five Spanish classes in high school, two in college, and an intensive week-long course abroad, around 1,000 hours, not counting homework. I should be fluent. Instead, I ended up with a few memorized conjugation tables and a terrible accent. Why? Classroom teaching often uses English, led by non-native speakers who speak with non-native accents. This means you're not getting enough authentic input to build a true \"internal representation\" of the language (that's linguist-speak for your subconscious knowledge). Worse, speaking from day one without mastering pronunciation cements bad habits into your language speaking ability. Many teachers claim a non-native accent shows your journey. I disagree. Accent is one of the most important aspects of learning any language and a lot of attention deserves to be paid to it. My French accent is far better than my Spanish one, and the difference in how I'm treated when speaking is night and day. When speaking French, people assume I am much more fluent than I am, often using words and a rate of speech they would never use with a learner at my level. When speaking Spanish, many would underestimate my ability, speaking slower or even switching to English when they could. A good accent triggers something subconscious in the mind of a native speaker, even if your grammar isn't perfect.")
                        .font(.system(size: 15))
                        .foregroundColor(.white.opacity(0.8))
                        .lineSpacing(5)
                }
                
                // The Duolingo Approach
                VStack(alignment: .leading, spacing: 10) {
                    Text("The Duolingo Approach")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(Color(red: 255/256, green: 76/256, blue: 76/256))
                    
                    Text("It's essentially a phone game for kids. It's fun for beginners but offers almost no real input from native speakers, leaving you unprepared for actual conversations.")
                        .font(.system(size: 15))
                        .foregroundColor(.white.opacity(0.8))
                        .lineSpacing(5)
                }
                
                // The Speak-from-Day-One Approach
                VStack(alignment: .leading, spacing: 10) {
                    Text("The Speak-from-Day-One Approach")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(Color(red: 255/256, green: 76/256, blue: 76/256))
                    
                    Text("New apps like Speak push early speaking, but this is the worst thing you can do for your accent. Speaking before you've absorbed sufficient native speech cements pronunciation errors that are hard to unlearn. True fluency is not being able to recite prearranged phrases. At LiNGUiD, we prioritize understanding first, so that meaningful communication comes naturally.")
                        .font(.system(size: 15))
                        .foregroundColor(.white.opacity(0.8))
                        .lineSpacing(5)
                }
                
                // The LiNGUiD Approach
                VStack(alignment: .leading, spacing: 10) {
                    Text("The LiNGUiD Approach")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(Color(red: 76/256, green: 255/256, blue: 76/256))
                    
                    Text("Humans are built to master languages. It's in our DNA. The trick is doing it organically, like babies do. The most effective learners surround themselves with their target language. Years ago, this meant moving to a new country. Today, your digital world makes it easier than ever. LiNGUiD turns your scrolling habit into a powerful language-learning tool. Every video you watch is in your target language, featuring native speakers tailored to your level. You can choose to passively scroll and absorb or actively save words to your vocabulary bank. Want to practice speaking? Connect with our community of native speakers for authentic language exchange. LiNGUiD brings everything necessary to learn the right way into one convenient place.")
                        .font(.system(size: 15))
                        .foregroundColor(.white.opacity(0.8))
                        .lineSpacing(5)
                }
                
                // Closing
                Text("Whether you're a beginner taking your first steps or an experienced learner chasing native-like fluency, LiNGUiD makes every moment count. Happy scrolling, and welcome to your journey to fluency!")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white)
                    .lineSpacing(6)
                    .padding(.top, 16)
                    .padding(.bottom, 40)
            }
            .padding(.horizontal, 24)
        }
        .background(
            Color.black
                .ignoresSafeArea()
        )
        .navigationBarTitleDisplayMode(.inline)
    }
}
