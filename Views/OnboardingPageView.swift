import SwiftUI

struct OnboardingPageView: View {
    let index: Int

    var body: some View {
        ZStack{
            Color.black.edgesIgnoringSafeArea(.all)
            VStack(spacing: 00) {

                Group {
                    switch index {
                    case 0:
                        VStack(spacing: 00) {
                            Text("Select your native Language")
                                .font(.system(size: 24, weight: .bold))
                                .foregroundColor(.white)
                                .multilineTextAlignment(.center)
                                .padding(.top, 20)
                            
                            Text("\nYou may select one or more\n\n")
                                .font(.system(size: 17))
                                .foregroundColor(.white)
                                .multilineTextAlignment(.center)
                            
                        }
                        
                        
                        
                    case 1:
                        VStack(spacing: 00) {
                            Text("Select your \n target Language")
                                .font(.system(size: 24, weight: .bold))
                                .foregroundColor(.white)
                                .multilineTextAlignment(.center)
                                .padding(.top, 20)
                            
                        }

                    case 2:
                        VStack(spacing: 00) {
                            Image("AppLogo")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 290, height: 100, alignment: .center) // Adjust size as needed
                                .padding(.top, 30)
                        }
                        
                        Spacer(minLength: 50)
                        ZStack(){
                            VStack(spacing: 00) {
                                Text("Zero to Fluent\nthe easy way")
                                    .font(.system(size: 24, weight: .bold))
                                    .foregroundColor(.white)
                                    .multilineTextAlignment(.center)
                                    .padding()
                                
                                Text("\nTo get the most out of LiNGUiD, stop\ncaring about understanding every word.\nThe more relaxed you are, the more\nefficiently you will acquire your target\nlanguage. LiNGUiD is the best way to\nachieve true immersion. Forget\ndoomscrolling. From now on, you will be\nlanguage scrolling to fluency. Now all\nthe time you spend swiping will be time\nspent acquiring.\n")
                                    .font(.system(size: 17))
                                    .foregroundColor(.white)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal, 10)
                            }
                            .padding()
                            .background(Color(red: 124/255, green: 58/255, blue: 237/255))
                            .cornerRadius(8)
                            .padding()

                        }
                        Spacer()
                        
                        
                    default:
                        Text("Unknown Page")
                            .foregroundColor(.red)
                    }
                }
                Spacer()
            }
        }
    }
}


//struct OnboardingPageView_Previews: PreviewProvider {
//    static var previews: some View {
//        OnboardingPageView(index: 3)
//    }
//}
